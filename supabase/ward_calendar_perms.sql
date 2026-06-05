-- =============================================================================
-- ward_calendar_perms.sql — ward 편집 / 일정 삭제 권한 제한
--   · ward_status 편집(UPDATE/INSERT): 관리자 또는 직군(교실·의국·간호사)만
--   · calendar_events 삭제: 작성자 본인 / 관리자 / 직군(교실·의국·비서). (작성=누구나는 유지)
-- 실행 순서: ... room_manage.sql 이후 (moim_is_admin 필요)
-- =============================================================================

-- 현재 로그인 사용자의 직군
CREATE OR REPLACE FUNCTION public.moim_my_member_type()
RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT member_type FROM public.profiles WHERE id = auth.uid();
$$;
GRANT EXECUTE ON FUNCTION public.moim_my_member_type() TO authenticated;

-- ward_status 편집: 관리자 또는 직군 교실/의국/간호사 ("병동")
DROP POLICY IF EXISTS "ward_status_update" ON public.ward_status;
CREATE POLICY "ward_status_update" ON public.ward_status FOR UPDATE TO authenticated
  USING      (public.moim_is_admin() OR public.moim_my_member_type() IN ('교실','의국','간호사'))
  WITH CHECK (public.moim_is_admin() OR public.moim_my_member_type() IN ('교실','의국','간호사'));

DROP POLICY IF EXISTS "ward_status_insert" ON public.ward_status;
CREATE POLICY "ward_status_insert" ON public.ward_status FOR INSERT TO authenticated
  WITH CHECK (public.moim_is_admin() OR public.moim_my_member_type() IN ('교실','의국','간호사'));

-- calendar_events 삭제: 작성자 본인 / 관리자 / 직군 교실·의국·비서·심리실
GRANT DELETE ON public.calendar_events TO authenticated;
DROP POLICY IF EXISTS "calendar_events_delete" ON public.calendar_events;
CREATE POLICY "calendar_events_delete" ON public.calendar_events FOR DELETE TO authenticated
  USING (
    owner_id = auth.uid()
    OR public.moim_is_admin()
    OR public.moim_my_member_type() IN ('교실','의국','비서','심리실')
  );

NOTIFY pgrst, 'reload schema';
-- =============================================================================
