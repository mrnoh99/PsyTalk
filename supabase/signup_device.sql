-- =============================================================================
-- signup_device.sql — (웹) 가입 시 사용 핸드폰 종류 + 앱 설치용 연결 이메일
--   · profiles.device_type:  'iphone' | 'android' (웹 가입 폼에서만 수집)
--   · profiles.device_email: 앱 설치용 연결 이메일(애플ID/구글계정). TestFlight/내부테스터 초대용.
--   · 가입 메타데이터(device_type·device_email)를 profiles 에 채움(moim_fill_signup_extra 갱신).
-- 실행 순서: ... member_contact_email.sql 이후 (moim_fill_signup_extra 존재)
-- 실행: Supabase SQL Editor (1회)
-- =============================================================================

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS device_type text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS device_email text;

-- 가입 시 phone·intro·email·device_type·device_email 을 함께 채움
CREATE OR REPLACE FUNCTION public.moim_fill_signup_extra()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE meta jsonb; uemail text;
BEGIN
  SELECT raw_user_meta_data, email INTO meta, uemail FROM auth.users WHERE id = NEW.id;
  IF meta IS NOT NULL THEN
    NEW.phone        := COALESCE(NEW.phone, NULLIF(trim(meta ->> 'phone'), ''));
    NEW.intro        := COALESCE(NEW.intro, NULLIF(trim(meta ->> 'intro'), ''));
    NEW.device_type  := COALESCE(NEW.device_type, NULLIF(trim(meta ->> 'device_type'), ''));
    NEW.device_email := COALESCE(NEW.device_email, NULLIF(trim(meta ->> 'device_email'), ''));
  END IF;
  NEW.email := COALESCE(NEW.email, uemail);
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_profiles_fill_signup_extra ON public.profiles;
CREATE TRIGGER trg_profiles_fill_signup_extra
  BEFORE INSERT ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.moim_fill_signup_extra();

NOTIFY pgrst, 'reload schema';
-- =============================================================================
