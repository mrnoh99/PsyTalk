-- =============================================================================
-- gcal_sync.sql — 주간 학술활동 방 ↔ Google Calendar 양방향(2-way) 동기화
--   · 인증: 서비스 계정 (Edge Function 이 서버에서 읽기/쓰기)
--   · 충돌: 마지막 수정 우선 (last-write-wins, updated 시각 비교)
--   · 첨부: 공유 드라이브 폴더 경유(설정 시). 미설정이면 첨부만 건너뜀.
--   실행 순서: ... secretary_perms.sql → (이 파일) gcal_sync.sql
--   실행 후: gcal_sync 행에 실제 google_calendar_id(+drive_folder_id) 입력, enabled=true.
--   사전 설정·배포는 docs/GCAL_SYNC_SETUP.md 참고.
-- =============================================================================

-- 1) calendar_events 동기화 컬럼 ---------------------------------------------
ALTER TABLE public.calendar_events ADD COLUMN IF NOT EXISTS google_event_id text;
ALTER TABLE public.calendar_events ADD COLUMN IF NOT EXISTS google_etag      text;
ALTER TABLE public.calendar_events ADD COLUMN IF NOT EXISTS gcal_updated_at  timestamptz;

CREATE UNIQUE INDEX IF NOT EXISTS calendar_events_google_event_id
  ON public.calendar_events(google_event_id) WHERE google_event_id IS NOT NULL;

-- 2) 동기화 설정 (방 ↔ 구글 캘린더 1:1) -------------------------------------
CREATE TABLE IF NOT EXISTS public.gcal_sync (
  room_id            uuid PRIMARY KEY REFERENCES public.rooms(id) ON DELETE CASCADE,
  google_calendar_id text NOT NULL,
  drive_folder_id    text,                       -- 첨부 업로드용 공유 드라이브 폴더(선택)
  sync_token         text,                       -- events.list 증분 토큰
  initial_days       int  NOT NULL DEFAULT 60,   -- 최초 동기화 시 과거 N일부터
  enabled            boolean NOT NULL DEFAULT true,
  last_synced_at     timestamptz,
  last_status        text
);
ALTER TABLE public.gcal_sync ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS gcal_sync_admin ON public.gcal_sync;
CREATE POLICY gcal_sync_admin ON public.gcal_sync FOR ALL TO authenticated
  USING (public.moim_is_superadmin()) WITH CHECK (public.moim_is_superadmin());

-- 초기 행(주간 학술활동 방). google_calendar_id 를 실제 값으로 바꾸고 enabled=true 로.
INSERT INTO public.gcal_sync (room_id, google_calendar_id, enabled)
VALUES ('11111111-1111-1111-1111-111111110012', 'REPLACE_WITH_GOOGLE_CALENDAR_ID', false)
ON CONFLICT (room_id) DO NOTHING;

-- 3) 삭제 톰스톤 (앱에서 지운 일정을 구글에서도 삭제) ------------------------
CREATE TABLE IF NOT EXISTS public.gcal_deletions (
  google_event_id text PRIMARY KEY,
  room_id         uuid NOT NULL,
  deleted_at      timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.gcal_deletions ENABLE ROW LEVEL SECURITY;  -- 정책 없음 = service_role 만

-- 4) 첨부 매핑 (앱 첨부 URL ↔ Drive 파일 id) --------------------------------
CREATE TABLE IF NOT EXISTS public.gcal_attachments (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id     uuid NOT NULL REFERENCES public.calendar_events(id) ON DELETE CASCADE,
  app_url      text,                 -- room-files 공개 URL (앱쪽)
  drive_file_id text,                -- Drive 파일 id (구글쪽)
  file_name    text,
  created_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (event_id, drive_file_id)
);
ALTER TABLE public.gcal_attachments ENABLE ROW LEVEL SECURITY;  -- 정책 없음 = service_role 만

-- 5) 헬퍼: 방이 동기화 대상인가 --------------------------------------------
CREATE OR REPLACE FUNCTION public.moim_gcal_is_synced_room(p_room uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.gcal_sync WHERE room_id = p_room AND enabled);
$$;

-- 동기화 대상 일정의 작성자로 쓸 superadmin id
CREATE OR REPLACE FUNCTION public.moim_gcal_superadmin_id()
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT id FROM public.profiles WHERE role = 'superadmin' ORDER BY created_at LIMIT 1;
$$;

-- 6) 트리거: 앱 변경 시 updated_at 갱신(=푸시 대상 표시). import 중이면 건드리지 않음.
--    import 는 RPC 안에서 set_config('app.gcal_importing','on',true) 로 표시.
CREATE OR REPLACE FUNCTION public.moim_gcal_touch()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF current_setting('app.gcal_importing', true) = 'on' THEN
    RETURN NEW;
  END IF;
  IF public.moim_gcal_is_synced_room(NEW.room_id) THEN
    NEW.updated_at := now();
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_gcal_touch ON public.calendar_events;
CREATE TRIGGER trg_gcal_touch BEFORE INSERT OR UPDATE ON public.calendar_events
  FOR EACH ROW EXECUTE FUNCTION public.moim_gcal_touch();

-- 7) 트리거: 앱 삭제 시 톰스톤 기록. import 중이면 생략.
CREATE OR REPLACE FUNCTION public.moim_gcal_tombstone()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF current_setting('app.gcal_importing', true) = 'on' THEN
    RETURN OLD;
  END IF;
  IF OLD.google_event_id IS NOT NULL AND public.moim_gcal_is_synced_room(OLD.room_id) THEN
    INSERT INTO public.gcal_deletions(google_event_id, room_id)
    VALUES (OLD.google_event_id, OLD.room_id)
    ON CONFLICT (google_event_id) DO NOTHING;
  END IF;
  RETURN OLD;
END $$;

DROP TRIGGER IF EXISTS trg_gcal_tombstone ON public.calendar_events;
CREATE TRIGGER trg_gcal_tombstone BEFORE DELETE ON public.calendar_events
  FOR EACH ROW EXECUTE FUNCTION public.moim_gcal_tombstone();

-- 8) Edge Function 용 RPC (service_role 전용) -------------------------------

-- 활성 동기화 설정 목록
CREATE OR REPLACE FUNCTION public.moim_gcal_config()
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT COALESCE(jsonb_agg(to_jsonb(g)), '[]'::jsonb) FROM public.gcal_sync g WHERE enabled;
$$;

CREATE OR REPLACE FUNCTION public.moim_gcal_set_token(p_room uuid, p_token text)
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  UPDATE public.gcal_sync SET sync_token = p_token WHERE room_id = p_room;
$$;

CREATE OR REPLACE FUNCTION public.moim_gcal_set_status(p_room uuid, p_status text)
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  UPDATE public.gcal_sync SET last_status = p_status, last_synced_at = now() WHERE room_id = p_room;
$$;

-- Pull(구글→앱) 일괄 적용: last-write-wins. p_changes = [{google_event_id,status,title,
--   start_at,place,link,description,keywords[],etag,updated}]
CREATE OR REPLACE FUNCTION public.moim_gcal_apply_pull(p_room uuid, p_changes jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  c jsonb; v_owner uuid; v_id uuid; v_upd timestamptz; v_gupd timestamptz;
  applied int := 0; removed int := 0; skipped int := 0;
BEGIN
  PERFORM set_config('app.gcal_importing', 'on', true);
  v_owner := public.moim_gcal_superadmin_id();

  FOR c IN SELECT value FROM jsonb_array_elements(p_changes) AS value
  LOOP
    v_gupd := NULLIF(c->>'updated','')::timestamptz;
    SELECT id, updated_at INTO v_id, v_upd FROM public.calendar_events
      WHERE google_event_id = c->>'google_event_id';

    IF (c->>'status') = 'cancelled' THEN
      IF v_id IS NOT NULL THEN
        DELETE FROM public.calendar_events WHERE id = v_id;
        removed := removed + 1;
      END IF;
      CONTINUE;
    END IF;

    IF v_id IS NOT NULL THEN
      IF v_upd IS NOT NULL AND v_gupd IS NOT NULL AND v_upd > v_gupd THEN
        skipped := skipped + 1;          -- 앱이 더 최신 → 다음 push 에서 구글로
        CONTINUE;
      END IF;
      UPDATE public.calendar_events SET
        title = c->>'title',
        start_at = (c->>'start_at')::timestamptz,
        place = c->>'place',
        link = c->>'link',
        description = c->>'description',
        keywords = COALESCE((SELECT array_agg(x) FROM jsonb_array_elements_text(c->'keywords') AS x), '{}'),
        google_etag = c->>'etag',
        gcal_updated_at = v_gupd,
        updated_at = COALESCE(v_gupd, now())
      WHERE id = v_id;
      applied := applied + 1;
    ELSE
      INSERT INTO public.calendar_events
        (room_id, title, start_at, place, link, description, keywords, owner_id,
         google_event_id, google_etag, gcal_updated_at, updated_at)
      VALUES
        (p_room, c->>'title', (c->>'start_at')::timestamptz, c->>'place', c->>'link',
         c->>'description',
         COALESCE((SELECT array_agg(x) FROM jsonb_array_elements_text(c->'keywords') AS x), '{}'),
         v_owner, c->>'google_event_id', c->>'etag', v_gupd, COALESCE(v_gupd, now()));
      applied := applied + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('applied', applied, 'removed', removed, 'skipped', skipped);
END $$;

-- 구글 event_id 로 앱 일정 id 조회(첨부 pull 시 매칭용)
CREATE OR REPLACE FUNCTION public.moim_gcal_event_id_for(p_google_event_id text)
RETURNS uuid LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT id FROM public.calendar_events WHERE google_event_id = p_google_event_id;
$$;

-- Push(앱→구글) 대상: 신규(google_event_id NULL) 또는 앱이 더 최신
CREATE OR REPLACE FUNCTION public.moim_gcal_dirty_rows(p_room uuid)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
     'id', id, 'google_event_id', google_event_id, 'google_etag', google_etag,
     'title', title, 'start_at', start_at, 'place', place, 'link', link,
     'description', description, 'keywords', to_jsonb(keywords),
     'updated_at', updated_at,
     'attachment_urls', to_jsonb(attachment_urls),
     'attachment_names', to_jsonb(attachment_names)
  )), '[]'::jsonb)
  FROM public.calendar_events
  WHERE room_id = p_room
    AND (google_event_id IS NULL OR gcal_updated_at IS NULL OR updated_at > gcal_updated_at);
$$;

-- Push 완료 표시: updated_at == gcal_updated_at 로 맞춰 더는 dirty 아님
CREATE OR REPLACE FUNCTION public.moim_gcal_mark_pushed(
  p_id uuid, p_google_event_id text, p_etag text, p_pushed_updated timestamptz)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM set_config('app.gcal_importing','on', true);
  -- updated_at 도 구글 반영시각으로 맞춰 더는 dirty/echo 가 발생하지 않게 함
  UPDATE public.calendar_events
    SET google_event_id = p_google_event_id,
        google_etag     = p_etag,
        gcal_updated_at = p_pushed_updated,
        updated_at      = COALESCE(p_pushed_updated, updated_at)
  WHERE id = p_id;
END $$;

-- 첨부(앱) URL/이름 갱신 (구글→앱 첨부 내려받은 뒤). import 플래그로 dirty 방지.
CREATE OR REPLACE FUNCTION public.moim_gcal_set_attachments(
  p_id uuid, p_urls jsonb, p_names jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM set_config('app.gcal_importing','on', true);
  UPDATE public.calendar_events SET
    attachment_urls  = COALESCE((SELECT array_agg(x) FROM jsonb_array_elements_text(p_urls)  AS x), '{}'),
    attachment_names = COALESCE((SELECT array_agg(x) FROM jsonb_array_elements_text(p_names) AS x), '{}')
  WHERE id = p_id;
END $$;

-- 톰스톤(삭제 대기) 조회·정리
CREATE OR REPLACE FUNCTION public.moim_gcal_take_deletions(p_room uuid)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT COALESCE(jsonb_agg(jsonb_build_object('google_event_id', google_event_id)), '[]'::jsonb)
  FROM public.gcal_deletions WHERE room_id = p_room;
$$;

CREATE OR REPLACE FUNCTION public.moim_gcal_clear_deletion(p_google_event_id text)
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  DELETE FROM public.gcal_deletions WHERE google_event_id = p_google_event_id;
$$;

-- 첨부 매핑 조회/추가/삭제 (Edge Function 이 재업로드 방지에 사용)
CREATE OR REPLACE FUNCTION public.moim_gcal_attachment_map(p_event uuid)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
     'id', id, 'app_url', app_url, 'drive_file_id', drive_file_id, 'file_name', file_name)), '[]'::jsonb)
  FROM public.gcal_attachments WHERE event_id = p_event;
$$;

CREATE OR REPLACE FUNCTION public.moim_gcal_add_attachment_map(
  p_event uuid, p_app_url text, p_drive_file_id text, p_file_name text)
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  INSERT INTO public.gcal_attachments(event_id, app_url, drive_file_id, file_name)
  VALUES (p_event, p_app_url, p_drive_file_id, p_file_name)
  ON CONFLICT (event_id, drive_file_id) DO NOTHING;
$$;

CREATE OR REPLACE FUNCTION public.moim_gcal_del_attachment_map(p_event uuid, p_drive_file_id text)
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  DELETE FROM public.gcal_attachments WHERE event_id = p_event AND drive_file_id = p_drive_file_id;
$$;

-- 권한: service_role 만 호출(Edge Function). (authenticated 에는 부여하지 않음)
DO $$
DECLARE fn text;
BEGIN
  FOR fn IN
    SELECT 'public.' || p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')'
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname LIKE 'moim_gcal_%'
  LOOP
    EXECUTE 'REVOKE ALL ON FUNCTION ' || fn || ' FROM PUBLIC, anon, authenticated';
    EXECUTE 'GRANT EXECUTE ON FUNCTION ' || fn || ' TO service_role';
  END LOOP;
END $$;

NOTIFY pgrst, 'reload schema';

-- =============================================================================
-- 9) 자동 주기 동기화 (pg_net + pg_cron) — 5분마다 gcal-sync Edge Function 호출
--    먼저 대시보드 Database→Extensions 에서 pg_net, pg_cron 활성화.
--    아래 <PROJECT_REF>, <ANON_OR_SERVICE_KEY> 를 본인 값으로 바꿔 실행.
--    Authorization 은 anon 키(공개)면 충분(함수가 내부에서 service_role 사용).
--    (수동 동기화는 앱의 superadmin '🔄 동기화' 버튼으로도 가능)
-- =============================================================================
-- create extension if not exists pg_net;
-- create extension if not exists pg_cron;
-- do $$ begin perform cron.unschedule('moim_gcal_sync'); exception when others then null; end $$;
-- select cron.schedule('moim_gcal_sync', '*/5 * * * *', $cron$
--   select net.http_post(
--     url     := 'https://<PROJECT_REF>.functions.supabase.co/gcal-sync',
--     headers := jsonb_build_object('Content-Type','application/json',
--                                   'Authorization','Bearer <ANON_OR_SERVICE_KEY>'),
--     body    := '{}'::jsonb
--   );
-- $cron$);
--
-- 즉시 1회 테스트(5분 안 기다리고): 위 select net.http_post(...) 만 단독 실행.
-- 진단:
--   select jobname, schedule, active from cron.job;
--   select status, return_message, start_time from cron.job_run_details
--     where jobid=(select jobid from cron.job where jobname='moim_gcal_sync')
--     order by start_time desc limit 5;
--   select status_code, created from net._http_response order by created desc limit 5;
