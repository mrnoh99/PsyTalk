-- =============================================================================
-- room_manage.sql — 모임방 관리: 삭제 · 회원 내보내기 · 동일 이름 금지
-- 실행 순서: ... room_create.sql → admin_roles.sql → (이 파일) room_manage.sql
-- =============================================================================

-- 1) 동일 이름의 모임방(custom) 생성 금지 (DB 차원에서 강제)
--    기본 방(category<>'custom')은 제외. 이름은 앱에서 trim 후 저장.
CREATE UNIQUE INDEX IF NOT EXISTS rooms_custom_name_unique
  ON public.rooms (name) WHERE category = 'custom';

-- 2) RLS 재귀(rooms ↔ room_members) 방지용 헬퍼 (SECURITY DEFINER 로 RLS 우회)
--    room_members 정책 안에서 room_members 를 직접 서브쿼리하면 42P17 무한재귀 발생.
CREATE OR REPLACE FUNCTION public.moim_is_room_owner(p_room uuid)
RETURNS boolean
LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.rooms r
    WHERE r.id = p_room AND r.created_by = auth.uid()
  );
$$;

CREATE OR REPLACE FUNCTION public.moim_is_admin()
RETURNS boolean
LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role IN ('superadmin', 'admin')
  );
$$;

-- 내가 속한 방 id 목록 (room_members 정책·rooms 가시성에서 재귀 없이 사용)
CREATE OR REPLACE FUNCTION public.moim_my_room_ids()
RETURNS SETOF uuid
LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public AS $$
  SELECT room_id FROM public.room_members WHERE user_id = auth.uid();
$$;

GRANT EXECUTE ON FUNCTION public.moim_is_room_owner(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.moim_is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.moim_my_room_ids() TO authenticated;

DROP FUNCTION IF EXISTS public.moim_is_room_member(uuid);

-- 3) 방 삭제: 생성자(본인이 만든 방) 또는 전체관리자(superadmin)만.
--    일반 관리자(admin)는 방을 삭제할 수 없음 (방 삭제 = 콘솔의 superadmin / 본인 방의 생성자).
--    CASCADE 로 회원·메시지·일정·자료 함께 삭제.
GRANT DELETE ON TABLE public.rooms TO authenticated;
DROP POLICY IF EXISTS "rooms_delete_owner_admin" ON public.rooms;
CREATE POLICY "rooms_delete_owner_admin"
  ON public.rooms FOR DELETE TO authenticated
  USING (
    created_by = auth.uid()
    OR public.moim_is_superadmin()
  );

-- 4) 회원 목록 조회: 본인 / 방 생성자(자기 방) / 관리자
--    (방 생성자가 회원를 내보내려면 회원 목록을 볼 수 있어야 함)
DROP POLICY IF EXISTS "room_members_select" ON public.room_members;
DROP POLICY IF EXISTS "room_members_admin" ON public.room_members;
CREATE POLICY "room_members_select"
  ON public.room_members FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR room_id IN (SELECT public.moim_my_room_ids())
    OR public.moim_is_room_owner(room_members.room_id)
    OR public.moim_is_admin()
  );

-- 5) 회원 내보내기(삭제): 방 생성자 또는 관리자
DROP POLICY IF EXISTS "room_members_delete_owner_admin" ON public.room_members;
CREATE POLICY "room_members_delete_owner_admin"
  ON public.room_members FOR DELETE TO authenticated
  USING (
    public.moim_is_room_owner(room_members.room_id)
    OR public.moim_is_admin()
  );

-- 6) 구성원 초대(INSERT): 방 생성자 또는 관리자
DROP POLICY IF EXISTS "room_members_insert_self" ON public.room_members;
DROP POLICY IF EXISTS "room_members_insert_owner_admin" ON public.room_members;
CREATE POLICY "room_members_insert_owner_admin"
  ON public.room_members FOR INSERT TO authenticated
  WITH CHECK (
    public.moim_is_room_owner(room_id)
    OR public.moim_is_admin()
  );

-- 6b) 방 조회 가시성 — room_members 직접 서브쿼리 제거 (rooms↔room_members 재귀 방지)
DROP POLICY IF EXISTS "rooms_select_authenticated" ON public.rooms;
DROP POLICY IF EXISTS "rooms_select_visible" ON public.rooms;
CREATE POLICY "rooms_select_visible"
  ON public.rooms FOR SELECT TO authenticated
  USING (
    category <> 'custom'
    OR created_by = auth.uid()
    OR id IN (SELECT public.moim_my_room_ids())
    OR public.moim_is_admin()
  );

-- 7) 기존 모임방: 생성자가 room_members 에 없으면 보정 (0명·초대 불가 방지)
INSERT INTO public.room_members (room_id, user_id)
SELECT r.id, r.created_by
FROM public.rooms r
WHERE r.created_by IS NOT NULL
  AND r.category = 'custom'
  AND NOT EXISTS (
    SELECT 1 FROM public.room_members rm
    WHERE rm.room_id = r.id AND rm.user_id = r.created_by
  )
ON CONFLICT DO NOTHING;

NOTIFY pgrst, 'reload schema';
