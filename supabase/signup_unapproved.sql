-- =============================================================================
-- signup_unapproved.sql — 새 가입자는 '불승인(approved=false)' 으로 시작하도록 강제
-- 실행 순서: ... admin_roles.sql → (이 파일) signup_unapproved.sql
-- 목적: 가입 직후 바로 사용화면으로 들어가는 문제 해결.
--       기존 사용자/전체관리자는 그대로 두고, 앞으로의 신규 가입만 불승인으로.
-- =============================================================================

-- 1) approved 컬럼 보장 + 기본값을 false 로
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS approved boolean;
ALTER TABLE public.profiles ALTER COLUMN approved SET DEFAULT false;

-- 2) profiles 에 새 행이 INSERT 될 때 approved 를 무조건 false 로 강제
--    (가입 트리거 handle_new_user 가 무엇을 넣든, 컬럼 기본값이 무엇이든 관계없이 불승인)
CREATE OR REPLACE FUNCTION public.moim_force_unapproved()
RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  NEW.approved := false;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_profiles_force_unapproved ON public.profiles;
CREATE TRIGGER trg_profiles_force_unapproved
  BEFORE INSERT ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.moim_force_unapproved();

-- 3) 전체관리자(superadmin)는 항상 승인 상태 유지 (본인 잠금 방지)
UPDATE public.profiles SET approved = true WHERE role = 'superadmin';

NOTIFY pgrst, 'reload schema';

-- 확인:
--   select name, role, approved from public.profiles order by approved, role, name;
-- 새 가입 테스트 후 그 사람이 approved=false 로 들어오는지 확인하세요.
-- =============================================================================
