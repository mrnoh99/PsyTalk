-- =============================================================================
-- 관리자 콘솔: 앱에서 직접 역할 지정 (SQL 없이) — 전체관리자만 변경 가능
-- 실행 순서: ... install.sql → room_create.sql → admin_roles.sql (마지막)
-- =============================================================================

-- 전체관리자 여부 (RLS 재귀 방지를 위해 SECURITY DEFINER 로 profiles 직접 조회)
CREATE OR REPLACE FUNCTION public.is_superadmin()
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

GRANT EXECUTE ON FUNCTION public.is_superadmin() TO authenticated;

-- 프로필 수정: 본인 기본 정보는 본인이, 역할(role) 변경은 전체관리자만
DROP POLICY IF EXISTS "profiles_update_role" ON public.profiles;
CREATE POLICY "profiles_update_role"
  ON public.profiles FOR UPDATE TO authenticated
  USING (public.is_superadmin() OR auth.uid() = id)
  WITH CHECK (public.is_superadmin() OR auth.uid() = id);

NOTIFY pgrst, 'reload schema';
