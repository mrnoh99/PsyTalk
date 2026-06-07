-- =============================================================================
-- cleanup_members.sql — 테스트용: superadmin 제외 전체 회원 하드 삭제
-- -----------------------------------------------------------------------------
--   · superadmin(전체관리자, jsnoh@ajou.ac.kr / role=superadmin) 1명만 유지
--   · 모임방·DM 방 삭제, 기본 방(전체공지·학술활동)은 유지
--   · 상단 고정 3개 = 전체공지 + 학술활동(둘 다 rooms) + 잔여병실현황(ward_status 메모)
--     → 셋 모두 보존됩니다. (ward_status 는 행 유지, 작성자만 NULL 처리)
--   · 채팅·일정·자료실 데이터 전부 삭제(깨끗한 테스트 환경)
--   · 스토리지(room-files 버킷) 파일은 이 SQL로 지우지 않음 — 필요 시 대시보드에서 정리
-- ⚠️ 되돌릴 수 없습니다. Supabase SQL Editor 에서 [1] 확인 후 [2] 실행.
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────
-- [1] 삭제 대상 확인 — 먼저 이 SELECT 만 실행
-- ─────────────────────────────────────────────────────────────────────────
SELECT u.email, p.name, p.role, p.approved, p.withdrawn,
       (p.role = 'superadmin') AS keep
FROM public.profiles p
JOIN auth.users u ON u.id = p.id
ORDER BY keep DESC, p.name;

SELECT count(*) AS will_delete
FROM public.profiles
WHERE role IS DISTINCT FROM 'superadmin';


-- ─────────────────────────────────────────────────────────────────────────
-- [2] 실행 — superadmin 제외 전체 회원 + 관련 데이터 삭제
-- ─────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
  sa uuid;
BEGIN
  SELECT p.id INTO sa
    FROM public.profiles p
   WHERE p.role = 'superadmin'
   LIMIT 1;

  IF sa IS NULL THEN
    SELECT u.id INTO sa
      FROM auth.users u
     WHERE lower(u.email) = 'jsnoh@ajou.ac.kr'
     LIMIT 1;
  END IF;

  IF sa IS NULL THEN
    RAISE EXCEPTION 'superadmin 계정을 찾을 수 없습니다. protect_superadmin.sql 을 먼저 실행하세요.';
  END IF;

  -- 모임방·DM (메시지·일정·자료·멤버 CASCADE)
  DELETE FROM public.rooms
   WHERE category::text IN ('custom', 'direct')
      OR dm_key IS NOT NULL;

  -- 기본 방 포함 채팅·일정·자료 전부 비움
  DELETE FROM public.message_cross_posts;
  DELETE FROM public.messages;
  DELETE FROM public.room_files;
  DELETE FROM public.calendar_events;

  UPDATE public.ward_status
     SET updated_by = NULL
   WHERE updated_by IS DISTINCT FROM sa;

  UPDATE public.rooms
     SET created_by = NULL
   WHERE created_by IS DISTINCT FROM sa;

  -- 프로필 삭제(superadmin 행은 트리거로 보호) → room_members/reads/pins/writers CASCADE
  DELETE FROM public.profiles
   WHERE id IS DISTINCT FROM sa;

  -- auth 세션·토큰 정리
  BEGIN
    DELETE FROM auth.refresh_tokens WHERE user_id::text <> sa::text;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
  BEGIN
    DELETE FROM auth.sessions WHERE user_id IS DISTINCT FROM sa;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
  BEGIN
    DELETE FROM auth.identities WHERE user_id IS DISTINCT FROM sa;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  -- 계정 하드 삭제
  DELETE FROM auth.users WHERE id IS DISTINCT FROM sa;

  RAISE NOTICE '완료 — superadmin(%) 만 남겼습니다.', sa;
END $$;


-- ─────────────────────────────────────────────────────────────────────────
-- [3] 결과 확인
-- ─────────────────────────────────────────────────────────────────────────
SELECT u.email, p.name, p.role, p.approved
FROM public.profiles p
JOIN auth.users u ON u.id = p.id;

SELECT count(*) AS profiles FROM public.profiles;
SELECT count(*) AS auth_users FROM auth.users;
SELECT count(*) AS messages FROM public.messages;
SELECT count(*) AS custom_dm_rooms
FROM public.rooms
WHERE category::text IN ('custom', 'direct') OR dm_key IS NOT NULL;

NOTIFY pgrst, 'reload schema';

-- 테스트 회원이 다시 필요하면: seed_dummy_members.sql 실행
-- =============================================================================
