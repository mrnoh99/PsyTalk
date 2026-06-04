-- =============================================================================
-- 모임방 사용자 생성 (카톡처럼 누구나 방 생성) + 가시성
-- 실행 순서: ... seed_rooms.sql → install.sql → (마지막) room_create.sql
-- =============================================================================

-- 방 생성자 추적용 컬럼
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES public.profiles(id);

-- 사용자가 방을 만들 수 있도록 INSERT/UPDATE 권한
GRANT INSERT, UPDATE ON TABLE public.rooms TO authenticated;

-- 방 생성: 모임방(custom)만, 본인이 created_by 일 때
DROP POLICY IF EXISTS "rooms_insert_custom" ON public.rooms;
CREATE POLICY "rooms_insert_custom"
  ON public.rooms FOR INSERT TO authenticated
  WITH CHECK (category = 'custom' AND created_by = auth.uid());

-- 방 조회: 기본 방은 모두 / 모임방은 멤버·생성자·관리자만 (카톡식 비공개)
DROP POLICY IF EXISTS "rooms_select_authenticated" ON public.rooms;
DROP POLICY IF EXISTS "rooms_select_visible" ON public.rooms;
CREATE POLICY "rooms_select_visible"
  ON public.rooms FOR SELECT TO authenticated
  USING (
    category <> 'custom'
    OR created_by = auth.uid()
    OR EXISTS (SELECT 1 FROM public.room_members rm
               WHERE rm.room_id = rooms.id AND rm.user_id = auth.uid())
    OR EXISTS (SELECT 1 FROM public.profiles p
               WHERE p.id = auth.uid() AND p.role IN ('superadmin', 'admin'))
  );

-- 방 이름 수정: 생성자(만든 사람) 또는 관리자만 (기본 방은 created_by=NULL 이라 관리자만)
DROP POLICY IF EXISTS "rooms_update_owner_admin" ON public.rooms;
CREATE POLICY "rooms_update_owner_admin"
  ON public.rooms FOR UPDATE TO authenticated
  USING (
    created_by = auth.uid()
    OR EXISTS (SELECT 1 FROM public.profiles p
               WHERE p.id = auth.uid() AND p.role IN ('superadmin', 'admin'))
  )
  WITH CHECK (
    created_by = auth.uid()
    OR EXISTS (SELECT 1 FROM public.profiles p
               WHERE p.id = auth.uid() AND p.role IN ('superadmin', 'admin'))
  );

-- 방 멤버 추가: 인증 사용자(생성자가 참석자 지정) 허용 (admin 전용 정책에 더해 OR)
DROP POLICY IF EXISTS "room_members_insert_self" ON public.room_members;
CREATE POLICY "room_members_insert_self"
  ON public.room_members FOR INSERT TO authenticated
  WITH CHECK (true);

NOTIFY pgrst, 'reload schema';
