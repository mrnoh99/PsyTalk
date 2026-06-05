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

-- 방 조회: room_manage.sql 의 moim_my_room_ids() 로 최종 정의 (여기서는 재귀 없는 초기 버전)
DROP POLICY IF EXISTS "rooms_select_authenticated" ON public.rooms;
DROP POLICY IF EXISTS "rooms_select_visible" ON public.rooms;
CREATE POLICY "rooms_select_visible"
  ON public.rooms FOR SELECT TO authenticated
  USING (
    category <> 'custom'
    OR created_by = auth.uid()
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

-- 방 회원 추가: 생성자·관리자만 (상세 정책은 room_manage.sql 의 room_members_insert_owner_admin)
-- room_manage.sql 미실행 환경용 폴백 — 생성자 또는 관리자
DROP POLICY IF EXISTS "room_members_insert_self" ON public.room_members;
DROP POLICY IF EXISTS "room_members_insert_owner_admin" ON public.room_members;
CREATE POLICY "room_members_insert_owner_admin"
  ON public.room_members FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.rooms r
            WHERE r.id = room_id AND r.created_by = auth.uid() AND r.category = 'custom')
    OR EXISTS (SELECT 1 FROM public.profiles p
               WHERE p.id = auth.uid() AND p.role IN ('superadmin', 'admin'))
  );

NOTIFY pgrst, 'reload schema';
