-- =============================================================================
-- room_manage.sql — 모임방 관리: 삭제 · 멤버 내보내기 · 동일 이름 금지
-- 실행 순서: ... room_create.sql → admin_roles.sql → (이 파일) room_manage.sql
-- =============================================================================

-- 1) 동일 이름의 모임방(custom) 생성 금지 (DB 차원에서 강제)
--    기본 방(category<>'custom')은 제외. 이름은 앱에서 trim 후 저장.
CREATE UNIQUE INDEX IF NOT EXISTS rooms_custom_name_unique
  ON public.rooms (name) WHERE category = 'custom';

-- 2) RLS 재귀(rooms ↔ room_members) 방지용 헬퍼 (SECURITY DEFINER 로 RLS 우회)
CREATE OR REPLACE FUNCTION public.moim_is_room_owner(p_room uuid)
RETURNS boolean
LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.rooms r
    WHERE r.id = p_room AND r.created_by = auth.uid()
  );
$$;

-- 3) 방 삭제: 생성자 또는 관리자 (CASCADE 로 멤버·메시지·일정·자료 함께 삭제)
GRANT DELETE ON TABLE public.rooms TO authenticated;
DROP POLICY IF EXISTS "rooms_delete_owner_admin" ON public.rooms;
CREATE POLICY "rooms_delete_owner_admin"
  ON public.rooms FOR DELETE TO authenticated
  USING (
    created_by = auth.uid()
    OR EXISTS (SELECT 1 FROM public.profiles p
               WHERE p.id = auth.uid() AND p.role IN ('superadmin', 'admin'))
  );

-- 4) 멤버 목록 조회: 본인 / 방 생성자(자기 방) / 관리자
--    (방 생성자가 멤버를 내보내려면 멤버 목록을 볼 수 있어야 함)
DROP POLICY IF EXISTS "room_members_select" ON public.room_members;
CREATE POLICY "room_members_select"
  ON public.room_members FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR public.moim_is_room_owner(room_members.room_id)
    OR EXISTS (SELECT 1 FROM public.profiles p
               WHERE p.id = auth.uid() AND p.role IN ('superadmin', 'admin'))
  );

-- 5) 멤버 내보내기(삭제): 방 생성자 또는 관리자
DROP POLICY IF EXISTS "room_members_delete_owner_admin" ON public.room_members;
CREATE POLICY "room_members_delete_owner_admin"
  ON public.room_members FOR DELETE TO authenticated
  USING (
    public.moim_is_room_owner(room_members.room_id)
    OR EXISTS (SELECT 1 FROM public.profiles p
               WHERE p.id = auth.uid() AND p.role IN ('superadmin', 'admin'))
  );

NOTIFY pgrst, 'reload schema';
