-- =============================================================================
-- signup_extra_fields.sql — 가입 추가 정보(핸드폰·간단한 소개) + 핸드폰/이메일 로그인
--   · profiles.intro: 간단한 소개. profiles.phone: 핸드폰번호(이미 있으면 유지).
--   · 가입 시 메타데이터(phone·intro)를 profiles 에 자동 저장(BEFORE INSERT 트리거).
--   · moim_email_for_phone(phone): 핸드폰번호 → 이메일 조회(핸드폰 로그인용).
-- 실행 순서: ... protect_superadmin.sql 이후 (handle_new_user/profiles 존재 필요)
-- 실행: Supabase SQL Editor (1회)
-- =============================================================================

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS intro text;

-- 1) 가입 시 메타데이터(phone·intro)를 새 profiles 행에 채움.
--    handle_new_user 가 profiles 를 INSERT 할 때(=auth.users 이미 존재) 메타데이터를 읽어 보강.
CREATE OR REPLACE FUNCTION public.moim_fill_signup_extra()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE meta jsonb;
BEGIN
  SELECT raw_user_meta_data INTO meta FROM auth.users WHERE id = NEW.id;
  IF meta IS NOT NULL THEN
    NEW.phone := COALESCE(NEW.phone, NULLIF(trim(meta ->> 'phone'), ''));
    NEW.intro := COALESCE(NEW.intro, NULLIF(trim(meta ->> 'intro'), ''));
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_profiles_fill_signup_extra ON public.profiles;
CREATE TRIGGER trg_profiles_fill_signup_extra
  BEFORE INSERT ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.moim_fill_signup_extra();

-- 2) 핸드폰번호 → 이메일 조회 (핸드폰으로 로그인 시 이메일을 찾아 비밀번호 로그인).
--    숫자만 비교(하이픈·공백 무시). anon 에도 허용(로그인 전 호출).
CREATE OR REPLACE FUNCTION public.moim_email_for_phone(p_phone text)
RETURNS text
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT u.email
  FROM public.profiles p JOIN auth.users u ON u.id = p.id
  WHERE p.phone IS NOT NULL
    AND regexp_replace(p.phone, '[^0-9]', '', 'g') = regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g')
    AND length(regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g')) >= 9
  LIMIT 1;
$$;
GRANT EXECUTE ON FUNCTION public.moim_email_for_phone(text) TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
-- =============================================================================
