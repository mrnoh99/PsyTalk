-- =============================================================================
-- 관리자 콘솔: 앱에서 직접 역할 지정 (SQL 없이) — 전체관리자만 변경 가능
-- 실행 순서: ... install.sql → room_create.sql → admin_roles.sql (마지막)
--
-- 주의: 기존 DB 에 이미 is_superadmin() 이 있을 수 있어 고유 이름(moim_*)을 씁니다.
-- =============================================================================

-- 직전 시도에서 만들어졌을 수 있는 0-인자 is_superadmin() 정리 (있으면)
DROP FUNCTION IF EXISTS public.is_superadmin();

-- 전체관리자 여부 (RLS 재귀 방지를 위해 SECURITY DEFINER 로 profiles 직접 조회)
CREATE OR REPLACE FUNCTION public.moim_is_superadmin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'superadmin'
  );
$$;

GRANT EXECUTE ON FUNCTION public.moim_is_superadmin() TO authenticated;

-- 가입 승인: 관리자 승인 전까지 approved=false. 기존 사용자는 모두 true 로 보정.
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS approved boolean;
UPDATE public.profiles SET approved = true WHERE approved IS NULL;
ALTER TABLE public.profiles ALTER COLUMN approved SET DEFAULT false;
ALTER TABLE public.profiles ALTER COLUMN approved SET NOT NULL;

-- 프로필 수정(역할·이름·가입승인): 전체관리자만. (자가 승인/권한변경 차단)
DROP POLICY IF EXISTS "profiles_update_role" ON public.profiles;
CREATE POLICY "profiles_update_role"
  ON public.profiles FOR UPDATE TO authenticated
  USING (public.moim_is_superadmin())
  WITH CHECK (public.moim_is_superadmin());

NOTIFY pgrst, 'reload schema';
