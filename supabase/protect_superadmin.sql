-- =============================================================================
-- protect_superadmin.sql — 전체관리자(superadmin) 고정·보호
--   대상: jsnoh@ajou.ac.kr  (이름: 노재성 / 전화: 01025310730)
--   · 현재 상태를 superadmin + 승인(approved=true) + 이름·전화 로 보정
--   · 이후 누구도(앱·SQL 무관) 이 계정을 퇴출(미승인)·강등·삭제하거나
--     이름·전화를 바꿀 수 없게 트리거로 강제
-- 실행 순서: ... signup_unapproved.sql → (이 파일) protect_superadmin.sql
-- 실행: Supabase SQL Editor
-- =============================================================================

-- 0) 상수. 다른 계정/정보로 바꾸려면 이 값들만 수정(함수/쿼리에 동일하게 반영).
--      이메일: 'jsnoh@ajou.ac.kr'  ·  이름: '노재성'  ·  전화: '01025310730'

-- 0-1) phone 컬럼 보장 (profiles 에 전화번호 저장)
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone text;

-- 1) 현재 상태 보정: superadmin + 승인 + 이름(노재성) + 전화(01025310730)
--    ※ UPDATE 부터 세미콜론(;) 까지 '한 문장 전체'를 실행하세요. SET 줄만 따로 실행 금지.
UPDATE public.profiles
SET role = 'superadmin', approved = true, name = '노재성', phone = '01025310730'
WHERE id = (SELECT id FROM auth.users WHERE lower(email) = 'jsnoh@ajou.ac.kr');

-- 2) 보호 트리거: 이 계정의 role/approved/name/phone 을 항상 고정값으로 되돌림
--    (INSERT·UPDATE 모두. 누가 무엇을 시도하든 강등/미승인/이름·전화 변경 불가)
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
    NEW.name := '노재성';
    NEW.phone := '01025310730';
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
--   SELECT u.email, p.name, p.phone, p.role, p.approved
--   FROM public.profiles p JOIN auth.users u ON u.id = p.id
--   WHERE lower(u.email) = 'jsnoh@ajou.ac.kr';
-- 테스트: 위 계정을 approved=false / 이름·전화 변경으로 UPDATE 해도 고정값으로 유지됨.
-- =============================================================================
