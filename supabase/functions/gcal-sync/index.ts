// =============================================================================
// gcal-sync — 주간 학술활동 방 ↔ Google Calendar 양방향(2-way) 동기화
//   · 인증: 서비스 계정 (JWT RS256 → OAuth2 access token)
//   · 충돌: 마지막 수정 우선 (last-write-wins)
//   · 첨부: 공유 드라이브 폴더 경유 (drive_folder_id 설정 시). 미설정이면 첨부 건너뜀.
//
//   필요한 Secrets (supabase secrets set ...):
//     GCAL_SA_EMAIL        서비스 계정 이메일 (xxx@yyy.iam.gserviceaccount.com)
//     GCAL_SA_PRIVATE_KEY  서비스 계정 private_key (JSON 키의 그 값, \n 포함 가능)
//   (SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY 는 Edge 런타임이 자동 주입)
//
//   사전 설정·배포: docs/GCAL_SYNC_SETUP.md
//   배포:  supabase functions deploy gcal-sync
// =============================================================================
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const FILES_BUCKET = "room-files";
const SCOPES = "https://www.googleapis.com/auth/calendar https://www.googleapis.com/auth/drive";

// ── 유틸 ────────────────────────────────────────────────────────────────────
function b64url(buf: ArrayBuffer | Uint8Array): string {
  const bytes = buf instanceof Uint8Array ? buf : new Uint8Array(buf);
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
function b64urlStr(str: string): string {
  return b64url(new TextEncoder().encode(str));
}
function pemToDer(pem: string): Uint8Array {
  // 헤더 제거 후 base64 문자만 남김(따옴표·공백·줄바꿈 등 잘못 들어간 문자 제거)
  const body = pem
    .replace(/-----BEGIN [^-]+-----/, "")
    .replace(/-----END [^-]+-----/, "")
    .replace(/[^A-Za-z0-9+/=]/g, "");
  const raw = atob(body);
  const der = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) der[i] = raw.charCodeAt(i);
  return der;
}

// 서비스 계정 자격증명 로드: GCAL_SA_JSON(키파일 전체) 우선, 없으면 EMAIL+PRIVATE_KEY
function loadServiceAccount(): { email: string; key: string } {
  const raw = (Deno.env.get("GCAL_SA_JSON") ?? "").trim();
  if (raw) {
    const j = JSON.parse(raw);            // JSON.parse 가 \n 이스케이프를 알아서 처리
    return { email: j.client_email, key: j.private_key };
  }
  return {
    email: (Deno.env.get("GCAL_SA_EMAIL") ?? "").trim().replace(/^["']|["']$/g, ""),
    key: (Deno.env.get("GCAL_SA_PRIVATE_KEY") ?? "").trim().replace(/^["']|["']$/g, "").replace(/\\n/g, "\n"),
  };
}

// ── 서비스 계정 → access token ───────────────────────────────────────────────
let cachedToken: { token: string; exp: number } | null = null;
async function getAccessToken(): Promise<string> {
  if (cachedToken && cachedToken.exp > Date.now() + 60_000) return cachedToken.token;
  const sa = loadServiceAccount();
  const email = sa.email;
  const pk = sa.key;
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const claim = {
    iss: email, scope: SCOPES, aud: "https://oauth2.googleapis.com/token",
    iat: now, exp: now + 3600,
  };
  const unsigned = `${b64urlStr(JSON.stringify(header))}.${b64urlStr(JSON.stringify(claim))}`;
  const key = await crypto.subtle.importKey(
    "pkcs8", pemToDer(pk),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"],
  );
  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(unsigned));
  const jwt = `${unsigned}.${b64url(sig)}`;
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: jwt,
    }),
  });
  const j = await res.json();
  if (!j.access_token) throw new Error("토큰 발급 실패: " + JSON.stringify(j));
  cachedToken = { token: j.access_token, exp: Date.now() + (j.expires_in ?? 3600) * 1000 };
  return cachedToken.token;
}

async function gapi(token: string, url: string, init: RequestInit = {}): Promise<any> {
  const res = await fetch(url, {
    ...init,
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json", ...(init.headers ?? {}) },
  });
  if (res.status === 204) return null;
  const text = await res.text();
  let body: any = null;
  try { body = text ? JSON.parse(text) : null; } catch { body = text; }
  if (!res.ok) { const e: any = new Error(`gapi ${res.status}: ${text}`); e.status = res.status; throw e; }
  return body;
}

// ── 필드 매핑 ────────────────────────────────────────────────────────────────
const CAL = "https://www.googleapis.com/calendar/v3";
const DRIVE = "https://www.googleapis.com/drive/v3";
const DRIVE_UP = "https://www.googleapis.com/upload/drive/v3";

function eventStartISO(ev: any): string | null {
  const s = ev.start?.dateTime ?? (ev.start?.date ? `${ev.start.date}T00:00:00Z` : null);
  return s;
}
function toGoogleEventBody(row: any, attachments: any[]): any {
  const start = new Date(row.start_at);
  const end = new Date(start.getTime() + 60 * 60 * 1000); // 종료 = 시작+1시간
  const body: any = {
    summary: row.title ?? "",
    location: row.place ?? undefined,
    description: row.description ?? undefined,
    start: { dateTime: start.toISOString() },
    end: { dateTime: end.toISOString() },
    extendedProperties: { private: { moimKeywords: JSON.stringify(row.keywords ?? []) } },
  };
  if (attachments.length) body.attachments = attachments;
  return body;
}
function keywordsFromGoogle(ev: any): string[] {
  const raw = ev.extendedProperties?.private?.moimKeywords;
  if (raw) { try { return JSON.parse(raw); } catch { /* fallthrough */ } }
  return [];
}

// ── 메인 ────────────────────────────────────────────────────────────────────
const VERSION = "gcal-sync-v3";   // 배포 확인용 (curl 응답에 표시)
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  // 브라우저(웹 앱) 사전요청(preflight) 처리
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const summary: any[] = [];
  try {
    const token = await getAccessToken();
    const { data: cfgs } = await supabase.rpc("moim_gcal_config");
    for (const cfg of (cfgs ?? [])) {
      try {
        const r = await syncOne(supabase, token, cfg);
        await supabase.rpc("moim_gcal_set_status", { p_room: cfg.room_id, p_status: "ok " + JSON.stringify(r) });
        summary.push({ room: cfg.room_id, ...r });
      } catch (e) {
        await supabase.rpc("moim_gcal_set_status", { p_room: cfg.room_id, p_status: "error: " + String(e) });
        summary.push({ room: cfg.room_id, error: String(e) });
      }
    }
    return new Response(JSON.stringify({ ok: true, version: VERSION, summary }), { headers: { ...CORS, "Content-Type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, version: VERSION, error: String(e), summary }), {
      status: 200, headers: { ...CORS, "Content-Type": "application/json" },
    });
  }
});

async function syncOne(supabase: any, token: string, cfg: any) {
  const calId = encodeURIComponent(cfg.google_calendar_id);
  const room = cfg.room_id;
  const folder = cfg.drive_folder_id || null;

  // ============ PULL (구글 → 앱) ============
  const changes: any[] = [];
  const pulledWithAttach: any[] = [];
  let pageToken: string | undefined;
  let syncToken: string | undefined = cfg.sync_token ?? undefined;
  let nextSyncToken: string | undefined;
  let done = false;
  while (!done) {
    const params = new URLSearchParams({ singleEvents: "true", showDeleted: "true", maxResults: "250" });
    if (syncToken) params.set("syncToken", syncToken);
    else params.set("timeMin", new Date(Date.now() - (cfg.initial_days ?? 60) * 86400_000).toISOString());
    if (pageToken) params.set("pageToken", pageToken);
    let data: any;
    try {
      data = await gapi(token, `${CAL}/calendars/${calId}/events?${params}`);
    } catch (e: any) {
      if (e.status === 410) { // syncToken 만료 → 처음부터 전체 재동기화
        await supabase.rpc("moim_gcal_set_token", { p_room: room, p_token: null });
        syncToken = undefined; pageToken = undefined; changes.length = 0; pulledWithAttach.length = 0;
        continue;
      }
      throw e;
    }
    for (const ev of (data.items ?? [])) {
      if (ev.status === "cancelled") {
        changes.push({ google_event_id: ev.id, status: "cancelled" });
        continue;
      }
      const startISO = eventStartISO(ev);
      if (!startISO) continue;
      changes.push({
        google_event_id: ev.id, status: "confirmed", title: ev.summary ?? "",
        start_at: startISO, place: ev.location ?? null, link: ev.htmlLink ?? null,
        description: ev.description ?? null, keywords: keywordsFromGoogle(ev),
        etag: ev.etag ?? null, updated: ev.updated ?? null,
      });
      if (folder && Array.isArray(ev.attachments) && ev.attachments.length) {
        pulledWithAttach.push(ev);
      }
    }
    if (data.nextPageToken) { pageToken = data.nextPageToken; }
    else { nextSyncToken = data.nextSyncToken ?? nextSyncToken; done = true; }
  }

  let pullRes: any = { applied: 0, removed: 0, skipped: 0 };
  if (changes.length) {
    const { data } = await supabase.rpc("moim_gcal_apply_pull", { p_room: room, p_changes: changes });
    pullRes = data ?? pullRes;
  }
  if (nextSyncToken) await supabase.rpc("moim_gcal_set_token", { p_room: room, p_token: nextSyncToken });

  // 구글→앱 첨부 내려받기 (best-effort)
  if (folder) {
    for (const ev of pulledWithAttach) {
      try { await pullAttachments(supabase, token, room, ev); } catch (_) { /* best-effort */ }
    }
  }

  // ============ PUSH (앱 → 구글) ============
  let pushed = 0, deleted = 0;
  const { data: dirty } = await supabase.rpc("moim_gcal_dirty_rows", { p_room: room });
  for (const row of (dirty ?? [])) {
    try {
      const attachments = folder ? await pushAttachments(supabase, token, folder, row) : [];
      const body = toGoogleEventBody(row, attachments);
      let ev: any;
      if (row.google_event_id) {
        ev = await gapi(token, `${CAL}/calendars/${calId}/events/${row.google_event_id}?supportsAttachments=true`,
          { method: "PATCH", body: JSON.stringify(body) });
      } else {
        ev = await gapi(token, `${CAL}/calendars/${calId}/events?supportsAttachments=true`,
          { method: "POST", body: JSON.stringify(body) });
      }
      await supabase.rpc("moim_gcal_mark_pushed", {
        p_id: row.id, p_google_event_id: ev.id, p_etag: ev.etag ?? null,
        p_pushed_updated: ev.updated ?? new Date().toISOString(),
      });
      pushed++;
    } catch (e) { summaryPush(e); }
  }

  // 톰스톤(앱에서 삭제) → 구글 삭제
  const { data: dels } = await supabase.rpc("moim_gcal_take_deletions", { p_room: room });
  for (const d of (dels ?? [])) {
    try {
      await gapi(token, `${CAL}/calendars/${calId}/events/${d.google_event_id}`, { method: "DELETE" });
    } catch (e: any) { if (e.status !== 404 && e.status !== 410) { summaryPush(e); continue; } }
    await supabase.rpc("moim_gcal_clear_deletion", { p_google_event_id: d.google_event_id });
    deleted++;
  }

  return { ...pullRes, pushed, deleted };
  function summaryPush(_e: unknown) { /* 개별 실패는 무시(다음 주기 재시도) */ }
}

// 앱 첨부 → Drive 업로드 후 event.attachments 배열 반환
async function pushAttachments(supabase: any, token: string, folder: string, row: any): Promise<any[]> {
  const urls: string[] = row.attachment_urls ?? [];
  const names: string[] = row.attachment_names ?? [];
  const { data: mapData } = await supabase.rpc("moim_gcal_attachment_map", { p_event: row.id });
  const map: any[] = mapData ?? [];
  const byUrl = new Map(map.filter((m) => m.app_url).map((m) => [m.app_url, m]));

  // 새 첨부 업로드
  for (let i = 0; i < urls.length; i++) {
    const url = urls[i]; if (!url || byUrl.has(url)) continue;
    const name = names[i] ?? `file_${i}`;
    const bin = await fetch(url); if (!bin.ok) continue;
    const bytes = new Uint8Array(await bin.arrayBuffer());
    const mime = bin.headers.get("content-type") ?? "application/octet-stream";
    const fileId = await driveUpload(token, folder, name, bytes, mime);
    if (!fileId) continue;
    await driveShareAnyone(token, fileId);
    await supabase.rpc("moim_gcal_add_attachment_map", { p_event: row.id, p_app_url: url, p_drive_file_id: fileId, p_file_name: name });
    map.push({ app_url: url, drive_file_id: fileId, file_name: name });
  }
  // 현재 앱에 남아있는 첨부만 event.attachments 로
  const keep = new Set(urls);
  return map
    .filter((m) => m.drive_file_id && (!m.app_url || keep.has(m.app_url)))
    .map((m) => ({ fileId: m.drive_file_id, fileUrl: `https://drive.google.com/open?id=${m.drive_file_id}`, title: m.file_name }));
}

// 구글 event.attachments(Drive) → 내려받아 room-files 업로드 후 앱 일정에 반영
async function pullAttachments(supabase: any, token: string, room: string, ev: any) {
  const { data: eid } = await supabase.rpc("moim_gcal_event_id_for", { p_google_event_id: ev.id });
  if (!eid) return;
  const { data: mapData } = await supabase.rpc("moim_gcal_attachment_map", { p_event: eid });
  const map: any[] = mapData ?? [];
  const byFile = new Map(map.map((m) => [m.drive_file_id, m]));
  const bucket = supabase.storage.from(FILES_BUCKET);

  for (const att of ev.attachments) {
    const fileId = att.fileId; if (!fileId || byFile.has(fileId)) continue;
    const name = att.title ?? `gcal_${fileId}`;
    const res = await fetch(`${DRIVE}/files/${fileId}?alt=media&supportsAllDrives=true`,
      { headers: { Authorization: `Bearer ${token}` } });
    if (!res.ok) continue;
    const bytes = new Uint8Array(await res.arrayBuffer());
    const path = `rooms/${room}/gcal/${fileId}_${name}`.replace(/[^\w./-]/g, "_");
    await bucket.upload(path, bytes, { upsert: true, contentType: att.mimeType ?? "application/octet-stream" });
    const pub = bucket.getPublicUrl(path).data.publicUrl;
    await supabase.rpc("moim_gcal_add_attachment_map", { p_event: eid, p_app_url: pub, p_drive_file_id: fileId, p_file_name: name });
    map.push({ app_url: pub, drive_file_id: fileId, file_name: name });
  }
  // 앱 일정의 첨부 = 매핑된 app_url 전체
  const urls = map.filter((m) => m.app_url).map((m) => m.app_url);
  const fnames = map.filter((m) => m.app_url).map((m) => m.file_name);
  await supabase.rpc("moim_gcal_set_attachments", { p_id: eid, p_urls: urls, p_names: fnames });
}

async function driveUpload(token: string, folder: string, name: string, bytes: Uint8Array, mime: string): Promise<string | null> {
  const boundary = "moimbnd" + crypto.randomUUID();
  const meta = JSON.stringify({ name, parents: [folder] });
  const head = `--${boundary}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n${meta}\r\n--${boundary}\r\nContent-Type: ${mime}\r\n\r\n`;
  const tail = `\r\n--${boundary}--`;
  const body = new Blob([head, bytes, tail]);
  const res = await fetch(`${DRIVE_UP}/files?uploadType=multipart&supportsAllDrives=true&fields=id`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": `multipart/related; boundary=${boundary}` },
    body,
  });
  if (!res.ok) return null;
  return (await res.json()).id ?? null;
}
async function driveShareAnyone(token: string, fileId: string) {
  try {
    await fetch(`${DRIVE}/files/${fileId}/permissions?supportsAllDrives=true`, {
      method: "POST",
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify({ role: "reader", type: "anyone" }),
    });
  } catch { /* 조직 정책상 막힐 수 있음 — best-effort */ }
}
