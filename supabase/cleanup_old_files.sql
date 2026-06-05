-- =============================================================================
-- cleanup_old_files.sql — 첨부/자료 4주 자동정리 + 스토리지 90% 한도 관리
--   대상: 채팅 첨부(messages.type in image|file) + 자료실 직접 업로드(room_files.source='upload')
--   동작: 28일(4주) 지난 항목 → 스토리지 객체 + DB 행 삭제
--         + 스토리지 사용량이 한도의 90% 초과 시 '오래된 것부터' 추가 삭제
--   주의: 캘린더 일정 첨부는 건드리지 않음(예정 일정 보호).
-- 실행: ① Supabase 대시보드 Database → Extensions 에서 'pg_cron' 활성화
--       ② 이 파일 전체 실행 (함수 생성 + 매일 03:00(UTC) 스케줄)
-- =============================================================================

-- 0) URL → 스토리지 path 디코더 (%EA%B0%80 같은 한글 인코딩 복원)
CREATE OR REPLACE FUNCTION public.moim_url_decode(input text)
RETURNS text
LANGUAGE sql IMMUTABLE AS $$
  SELECT COALESCE(string_agg(
    CASE WHEN g.m[1] IS NOT NULL
         THEN convert_from(decode(replace(g.m[1], '%', ''), 'hex'), 'UTF8')
         ELSE g.m[2] END,
    '' ORDER BY g.ord), input)
  FROM regexp_matches(input, '((?:%[0-9a-fA-F]{2})+)|([^%]+)', 'g') WITH ORDINALITY AS g(m, ord);
$$;

-- 1) 정리 함수
CREATE OR REPLACE FUNCTION public.moim_cleanup_old_files()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  marker      text   := '/object/public/room-files/';
  limit_bytes bigint := 1073741824;   -- 1GB (Supabase 무료). 플랜에 맞게 수정.
  r           record;
  p           text;
  used        bigint;
BEGIN
  -- (A) 28일 지난 '채팅 첨부' 메시지 삭제 (스토리지 객체 + 메시지)
  FOR r IN
    SELECT id, attachment_url AS url FROM public.messages
    WHERE type IN ('image','file') AND attachment_url IS NOT NULL
      AND created_at < now() - interval '28 days'
  LOOP
    IF position(marker IN r.url) > 0 THEN
      p := public.moim_url_decode(substring(r.url FROM position(marker IN r.url) + length(marker)));
      DELETE FROM storage.objects WHERE bucket_id = 'room-files' AND name = p;
    END IF;
    DELETE FROM public.messages WHERE id = r.id;
  END LOOP;

  -- (B) 28일 지난 '자료실 직접 업로드' 삭제 (스토리지 객체 + room_files)
  FOR r IN
    SELECT id, file_url AS url FROM public.room_files
    WHERE source = 'upload' AND created_at < now() - interval '28 days'
  LOOP
    IF position(marker IN r.url) > 0 THEN
      p := public.moim_url_decode(substring(r.url FROM position(marker IN r.url) + length(marker)));
      DELETE FROM storage.objects WHERE bucket_id = 'room-files' AND name = p;
    END IF;
    DELETE FROM public.room_files WHERE id = r.id;
  END LOOP;

  -- (C) 스토리지 90% 초과 시: 오래된 첨부/자료부터 추가 삭제
  SELECT COALESCE(SUM((metadata->>'size')::bigint), 0) INTO used
    FROM storage.objects WHERE bucket_id = 'room-files';

  WHILE used > limit_bytes * 90 / 100 LOOP
    SELECT * INTO r FROM (
      SELECT 'msg'::text AS kind, id, attachment_url AS url, created_at AS at
        FROM public.messages WHERE type IN ('image','file') AND attachment_url IS NOT NULL
      UNION ALL
      SELECT 'file'::text, id, file_url, created_at
        FROM public.room_files WHERE source = 'upload'
    ) x ORDER BY x.at ASC LIMIT 1;
    EXIT WHEN NOT FOUND;

    IF position(marker IN r.url) > 0 THEN
      p := public.moim_url_decode(substring(r.url FROM position(marker IN r.url) + length(marker)));
      DELETE FROM storage.objects WHERE bucket_id = 'room-files' AND name = p;
    END IF;
    IF r.kind = 'msg' THEN DELETE FROM public.messages WHERE id = r.id;
    ELSE                   DELETE FROM public.room_files WHERE id = r.id; END IF;

    SELECT COALESCE(SUM((metadata->>'size')::bigint), 0) INTO used
      FROM storage.objects WHERE bucket_id = 'room-files';
  END LOOP;
END $$;

-- 2) 매일 03:00(UTC) 자동 실행 (pg_cron). 기존 동일 작업이 있으면 교체.
DO $$ BEGIN
  PERFORM cron.unschedule('moim_cleanup_old_files');
EXCEPTION WHEN OTHERS THEN NULL; END $$;

SELECT cron.schedule('moim_cleanup_old_files', '0 3 * * *',
                     $$ SELECT public.moim_cleanup_old_files(); $$);

-- 수동 실행/테스트:  SELECT public.moim_cleanup_old_files();
-- 스케줄 확인:       SELECT jobname, schedule FROM cron.job;
-- 보관 기간 변경:    위 함수의 interval '28 days' 수정 후 다시 실행.
-- =============================================================================
