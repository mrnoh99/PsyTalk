-- =============================================================================
-- member_contact_email.sql — profiles.email (auth.users 와 동기화)
--   회원 검색·회원 관리 화면에서 회원의 이메일을 작은 글씨로 표시하기 위해
--   profiles 에 email 컬럼을 두고 auth.users.email 과 동기화한다.
--   (전화번호 phone·자기소개 intro 는 signup_extra_fields.sql 에서 이미 존재)
-- 실행 순서: ... signup_extra_fields.sql 이후 (profiles·auth.users 존재 필요)
-- 실행: Supabase SQL Editor (1회)
-- =============================================================================

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email text;

-- 1) 기존 회원 backfill — auth.users 의 이메일을 profiles 로 복사
UPDATE public.profiles p
   SET email = u.email
  FROM auth.users u
 WHERE u.id = p.id
   AND p.email IS DISTINCT FROM u.email;

-- 2) 가입 시 profiles.email·phone·intro 를 함께 채움
--    (signup_extra_fields.sql 의 moim_fill_signup_extra 를 email 포함하도록 갱신)
CREATE OR REPLACE FUNCTION public.moim_fill_signup_extra()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE meta jsonb; uemail text;
BEGIN
  SELECT raw_user_meta_data, email INTO meta, uemail FROM auth.users WHERE id = NEW.id;
  IF meta IS NOT NULL THEN
    NEW.phone := COALESCE(NEW.phone, NULLIF(trim(meta ->> 'phone'), ''));
    NEW.intro := COALESCE(NEW.intro, NULLIF(trim(meta ->> 'intro'), ''));
  END IF;
  NEW.email := COALESCE(NEW.email, uemail);
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_profiles_fill_signup_extra ON public.profiles;
CREATE TRIGGER trg_profiles_fill_signup_extra
  BEFORE INSERT ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.moim_fill_signup_extra();

-- 3) auth.users.email 변경 시 profiles.email 자동 동기화
CREATE OR REPLACE FUNCTION public.moim_sync_email()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE public.profiles SET email = NEW.email WHERE id = NEW.id;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_users_sync_email ON auth.users;
CREATE TRIGGER trg_users_sync_email
  AFTER INSERT OR UPDATE OF email ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.moim_sync_email();

NOTIFY pgrst, 'reload schema';
-- =============================================================================
