// =============================================================================
// notify-message — 새 메시지가 들어오면 그 방 구성원(보낸이 제외)에게 OneSignal 푸시
//   트리거: Supabase Database Webhook (messages INSERT) → 이 함수 호출
//   필요한 Secrets (supabase secrets set ...):
//     ONESIGNAL_APP_ID, ONESIGNAL_REST_API_KEY
//   (SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY 는 Edge 런타임이 자동 주입)
//   배포:  supabase functions deploy notify-message
// =============================================================================
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  try {
    const body = await req.json();
    // Database Webhook payload: { type:'INSERT', table:'messages', record:{...} }
    const m = body.record ?? body;
    if (!m?.room_id || !m?.sender_id) return new Response("skip", { status: 200 });

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // 방 구성원 (모임방=room_members / 기본방=승인 전원), 보낸이 제외
    const { data: members } = await supabase.rpc("moim_room_member_ids", { p_room: m.room_id });
    const recipients = (members ?? [])
      .map((x: { user_id: string }) => x.user_id)
      .filter((id: string) => id !== m.sender_id);
    if (recipients.length === 0) return new Response("no recipients", { status: 200 });

    // 방 이름 · 보낸사람 이름
    const [{ data: room }, { data: sender }] = await Promise.all([
      supabase.from("rooms").select("name").eq("id", m.room_id).maybeSingle(),
      supabase.from("profiles").select("name").eq("id", m.sender_id).maybeSingle(),
    ]);
    const preview = m.type === "image" ? "📷 사진"
      : m.type === "file" ? `📎 ${m.attachment_name ?? "파일"}`
      : (m.content ?? "");
    const heading = room?.name ?? "새 메시지";
    const content = `${sender?.name ?? ""}: ${preview}`.trim();

    const res = await fetch("https://onesignal.com/api/v1/notifications", {
      method: "POST",
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        "Authorization": `Basic ${Deno.env.get("ONESIGNAL_REST_API_KEY")}`,
      },
      body: JSON.stringify({
        app_id: Deno.env.get("ONESIGNAL_APP_ID"),
        target_channel: "push",
        include_aliases: { external_id: recipients },
        headings: { en: heading, ko: heading },
        contents: { en: content, ko: content },
        data: { room_id: m.room_id },
      }),
    });
    const out = await res.text();
    return new Response(out, { status: res.ok ? 200 : 502 });
  } catch (e) {
    return new Response(`error: ${e}`, { status: 200 }); // 실패해도 메시지 전송엔 영향 없게 200
  }
});
