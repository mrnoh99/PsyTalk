-- =============================================================================
-- protect_superadmin.sql — 전체관리자(superadmin) 고정·보호
--   대상: jsnoh@ajou.ac.kr
--   · 현재 상태를 superadmin + 승인(approved=true) 으로 보정
--   · 이후 누구도(앱·SQL 무관) 이 계정을 퇴출(미승인)·강등·삭제할 수 없게 트리거로 강제
-- 실행 순서: ... signup_unapproved.sql → (이 파일) protect_superadmin.sql
-- 실행: Supabase SQL Editor
-- =============================================================================

-- 0) 이메일 상수 (대소문자 무시). 다른 계정으로 바꾸려면 이 값만 수정.
--    아래 함수/쿼리에서 'jsnoh@ajou.ac.kr' 를 그대로 사용합니다.

-- 1) 현재 상태 보정: superadmin + 승인
UPDATE public.profiles p
SET role = 'superadmin', approved = true
FROM auth.users u
WHERE p.id = u.id AND lower(u.email) = 'jsnoh@ajou.ac.kr';

-- 2) 보호 트리거: 이 계정의 role/approved 변경을 항상 superadmin/true 로 되돌림
--    (INSERT·UPDATE 모두. 누가 무엇을 시도하든 결과적으로 강등/미승인 불가)
CREATE OR REPLACE FUNCTION public.moim_protect_superadmin()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  em text;
BEGIN
  SELECT lower(email) INTO em FROM auth.users WHERE id = NEW.id;
  IF em = 'jsnoh@ajou.ac.kr' THEN
    NEW.role := 'superadmin';
    NEW.approved := true;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_profiles_protect_superadmin ON public.profiles;
CREATE TRIGGER trg_profiles_protect_superadmin
  BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.moim_protect_superadmin();

-- 3) 삭제 방지: 이 계정의 프로필은 삭제 불가
CREATE OR REPLACE FUNCTION public.moim_block_superadmin_delete()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  em text;
BEGIN
  SELECT lower(email) INTO em FROM auth.users WHERE id = OLD.id;
  IF em = 'jsnoh@ajou.ac.kr' THEN
    RAISE EXCEPTION '전체관리자 계정은 삭제할 수 없습니다.';
  END IF;
  RETURN OLD;
END $$;

DROP TRIGGER IF EXISTS trg_profiles_block_superadmin_delete ON public.profiles;
CREATE TRIGGER trg_profiles_block_superadmin_delete
  BEFORE DELETE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.moim_block_superadmin_delete();

NOTIFY pgrst, 'reload schema';

-- 확인:
--   SELECT u.email, p.role, p.approved
--   FROM public.profiles p JOIN auth.users u ON u.id = p.id
--   WHERE lower(u.email) = 'jsnoh@ajou.ac.kr';
-- 테스트: 위 계정을 approved=false 로 UPDATE 시도해도 다시 true 로 유지됨.
-- =============================================================================
