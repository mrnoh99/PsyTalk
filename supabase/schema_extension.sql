-- =============================================================================
-- 아주 정신 확장 스키마 (요구사항 반영)
-- rooms / profiles / messages 가 이미 있다고 가정
-- =============================================================================

-- 방 참석 (superadmin이 지정)
CREATE TABLE IF NOT EXISTS public.room_members (
  room_id uuid NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  PRIMARY KEY (room_id, user_id)
);

-- 공지방 지정 작성자 (restricted 방)
CREATE TABLE IF NOT EXISTS public.room_writers (
  room_id uuid NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  PRIMARY KEY (room_id, user_id)
);

-- 멀티 방 게시 (같은 내용을 다른 방에도)
CREATE TABLE IF NOT EXISTS public.message_cross_posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_message_id uuid NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
  target_room_id uuid NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (source_message_id, target_room_id)
);

-- 캘린더 일정
CREATE TABLE IF NOT EXISTS public.calendar_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id uuid NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
  title text NOT NULL,
  start_at timestamptz NOT NULL,
  place text,
  link text,
  scope text,
  description text,
  keywords text[] DEFAULT '{}',
  owner_id uuid NOT NULL REFERENCES public.profiles(id),
  attachment_url text,
  attachment_name text,
  attachment_desc text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- 자료실 직접 업로드
CREATE TABLE IF NOT EXISTS public.room_files (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id uuid NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
  file_name text NOT NULL,
  file_url text NOT NULL,
  description text,
  keywords text[] DEFAULT '{}',
  uploaded_by uuid NOT NULL REFERENCES public.profiles(id),
  source text NOT NULL DEFAULT 'upload', -- upload | calendar
  calendar_event_id uuid REFERENCES public.calendar_events(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- RLS
ALTER TABLE public.room_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_writers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_cross_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.calendar_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_files ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.room_members TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.room_writers TO authenticated;
GRANT SELECT, INSERT ON public.message_cross_posts TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.calendar_events TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.room_files TO authenticated;

-- 멤버: 본인이 속한 방만 조회
DROP POLICY IF EXISTS "room_members_select" ON public.room_members;
CREATE POLICY "room_members_select"
  ON public.room_members FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND p.role IN ('superadmin', 'admin')
  ));

-- superadmin/admin만 멤버·작성자 관리 (앱에서 service_role 또는 추후 세분화)
DROP POLICY IF EXISTS "room_members_admin" ON public.room_members;
CREATE POLICY "room_members_admin"
  ON public.room_members FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND p.role IN ('superadmin', 'admin')
  ));

DROP POLICY IF EXISTS "calendar_events_select" ON public.calendar_events;
CREATE POLICY "calendar_events_select"
  ON public.calendar_events FOR SELECT TO authenticated
  USING (true);

-- 일정 작성: 본인이 owner 로만 작성 (방 참석 제한은 room_members 연동 후 강화 예정)
DROP POLICY IF EXISTS "calendar_events_insert" ON public.calendar_events;
CREATE POLICY "calendar_events_insert"
  ON public.calendar_events FOR INSERT TO authenticated
  WITH CHECK (owner_id = auth.uid());

-- 일정 수정: 작성자 본인 + superadmin/admin (요구사항 6)
DROP POLICY IF EXISTS "calendar_events_update" ON public.calendar_events;
CREATE POLICY "calendar_events_update"
  ON public.calendar_events FOR UPDATE TO authenticated
  USING (
    owner_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role IN ('superadmin', 'admin'))
  );

-- 자료실: 모든 인증 사용자 조회 / 본인 업로드만 추가
DROP POLICY IF EXISTS "room_files_select" ON public.room_files;
CREATE POLICY "room_files_select"
  ON public.room_files FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "room_files_insert" ON public.room_files;
CREATE POLICY "room_files_insert"
  ON public.room_files FOR INSERT TO authenticated
  WITH CHECK (uploaded_by = auth.uid());

-- 프로필: 작성자·업로더 이름 표시를 위해 인증 사용자는 전체 조회 가능
-- (fix_signup.sql 의 profiles_select_own 을 대체)
DROP POLICY IF EXISTS "profiles_select_own" ON public.profiles;
DROP POLICY IF EXISTS "profiles_select_all" ON public.profiles;
CREATE POLICY "profiles_select_all"
  ON public.profiles FOR SELECT TO authenticated
  USING (true);

NOTIFY pgrst, 'reload schema';
