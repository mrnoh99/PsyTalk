-- =============================================================================
-- PsyTalk 한 번에 설정 (권한 + RLS)
-- Supabase Dashboard → SQL Editor → 이 파일 전체 Run
--
-- 권장 순서: fix_signup.sql → schema_extension.sql → seed_rooms.sql → install.sql
-- =============================================================================

GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;

-- 1) 테이블 권한 (permission denied / 42501 방지)
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.profiles TO service_role;
GRANT SELECT ON TABLE public.profiles TO anon;

GRANT SELECT ON TABLE public.rooms TO authenticated;
GRANT SELECT ON TABLE public.rooms TO service_role;
GRANT SELECT ON TABLE public.rooms TO anon;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.messages TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.messages TO service_role;

-- 2) RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- 3) 정책 (재실행 안전)
DROP POLICY IF EXISTS "profiles_select_own" ON public.profiles;
DROP POLICY IF EXISTS "profiles_insert_own" ON public.profiles;
DROP POLICY IF EXISTS "rooms_select_authenticated" ON public.rooms;
DROP POLICY IF EXISTS "messages_select_authenticated" ON public.messages;
DROP POLICY IF EXISTS "messages_insert_own" ON public.messages;

CREATE POLICY "profiles_select_own"
  ON public.profiles FOR SELECT TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "profiles_insert_own"
  ON public.profiles FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = id);

CREATE POLICY "rooms_select_authenticated"
  ON public.rooms FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "messages_select_authenticated"
  ON public.messages FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "messages_insert_own"
  ON public.messages FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = sender_id);

-- 4) API 스키마 캐시 갱신
NOTIFY pgrst, 'reload schema';
