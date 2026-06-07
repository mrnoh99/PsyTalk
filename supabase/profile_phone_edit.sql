-- =============================================================================
-- profile_phone_edit.sql — 내 정보에서 전화번호·핸드폰 종류 변경 + 전화번호 최종변경일 기록
--   · profiles.phone_updated_at: 전화번호를 마지막으로 입력/변경한 시각(회원명단 표시).
--   · moim_update_my_profile 에 p_phone·p_device_type 추가(본인만). 빈 값이면 기존 유지.
--   · 전화번호가 실제로 바뀔 때만 phone_updated_at 갱신(BEFORE UPDATE 트리거).
-- 실행 순서: ... profile_member_type.sql → signup_device.sql → (이 파일)
-- 실행: Supabase SQL Editor (1회)
-- =============================================================================

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone_updated_at timestamptz;

-- 기존 회원 backfill: 가입일(created_at) 기준 (없으면 now())
UPDATE public.profiles
   SET phone_updated_at = COALESCE(phone_updated_at, created_at, now())
 WHERE phone_updated_at IS NULL;

-- 전화번호가 바뀌면 최종변경일 갱신
CREATE OR REPLACE FUNCTION public.moim_track_phone_update()
RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.phone IS DISTINCT FROM OLD.phone THEN
    NEW.phone_updated_at := now();
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_profiles_track_phone ON public.profiles;
CREATE TRIGGER trg_profiles_track_phone
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.moim_track_phone_update();

-- moim_update_my_profile 에 전화번호·핸드폰 종류 추가 (4인자 구버전 제거 후 6인자로 재생성)
DROP FUNCTION IF EXISTS public.moim_update_my_profile(text, text, text, text);

CREATE OR REPLACE FUNCTION public.moim_update_my_profile(
  p_intro        text DEFAULT NULL,
  p_avatar_url   text DEFAULT NULL,
  p_color        text DEFAULT NULL,
  p_member_type  text DEFAULT NULL,
  p_phone        text DEFAULT NULL,
  p_device_type  text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  mt_udt text;
  mt     text;
  ph     text := NULLIF(trim(p_phone), '');
  dv     text := NULLIF(trim(p_device_type), '');
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION '로그인이 필요합니다.';
  END IF;

  IF dv IS NOT NULL AND dv NOT IN ('iphone','android') THEN
    RAISE EXCEPTION '핸드폰 종류는 iphone 또는 android 여야 합니다.';
  END IF;

  mt := NULLIF(trim(p_member_type), '');
  IF mt IS NOT NULL AND mt NOT IN (
    '교실','의국','심리실','연구실','PA','간호사','SW','보조원',
    '생명사랑','비서','의국동문','심리실 동문','기타'
  ) THEN
    RAISE EXCEPTION '허용되지 않은 직군입니다.';
  END IF;

  SELECT udt_name INTO mt_udt
  FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'member_type';

  IF mt IS NOT NULL AND EXISTS (
    SELECT 1 FROM pg_type t JOIN pg_namespace n ON t.typnamespace = n.oid
    WHERE n.nspname = 'public' AND t.typname = mt_udt AND t.typtype = 'e'
  ) THEN
    EXECUTE format(
      'UPDATE public.profiles SET intro=$1, avatar_url=$2, color=$3, member_type=$4::%I, '
      || 'phone=COALESCE($5,phone), device_type=COALESCE($6,device_type) WHERE id=$7',
      mt_udt
    ) USING p_intro, p_avatar_url, p_color, mt, ph, dv, auth.uid();
  ELSE
    UPDATE public.profiles
       SET intro       = p_intro,
           avatar_url  = p_avatar_url,
           color       = p_color,
           member_type = COALESCE(mt, member_type),
           phone       = COALESCE(ph, phone),
           device_type = COALESCE(dv, device_type)
     WHERE id = auth.uid();
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.moim_update_my_profile(text, text, text, text, text, text) TO authenticated;

NOTIFY pgrst, 'reload schema';
-- =============================================================================
