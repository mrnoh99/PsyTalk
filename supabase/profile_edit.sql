-- =============================================================================
-- profile_edit.sql — 내정보 변경: 자기소개(intro) + 방표식(아바타) 색상·사진
-- 실행 순서: ... account_reactivate.sql → protect_superadmin_password.sql → (이 파일)
-- -----------------------------------------------------------------------------
-- profiles 에 avatar_url(공개 사진 URL)·color(hex) 컬럼 추가.
-- 이름·이메일은 변경 불가(읽기전용). 비밀번호는 클라이언트에서 auth.updateUser 로 변경.
-- 본인 프로필의 intro/avatar_url/color 만 바꾸는 RPC (role·approved 등은 건드리지 않음).
--   → profiles UPDATE 정책이 superadmin 전용이므로, 본인 안전 컬럼만 RPC(SECURITY DEFINER)로 갱신.
-- =============================================================================

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS avatar_url text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS color      text;

CREATE OR REPLACE FUNCTION public.moim_update_my_profile(
  p_intro      text DEFAULT NULL,
  p_avatar_url text DEFAULT NULL,
  p_color      text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION '로그인이 필요합니다.';
  END IF;
  UPDATE public.profiles
     SET intro      = p_intro,
         avatar_url = p_avatar_url,
         color      = p_color
   WHERE id = auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION public.moim_update_my_profile(text, text, text) TO authenticated;

NOTIFY pgrst, 'reload schema';
