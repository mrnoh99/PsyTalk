-- =============================================================================
-- leave_account.sql — 방 나가기(본인) + 회원 탈퇴(본인)
--   · room_members: 본인 멤버십 삭제 허용(방 나가기) — 기존 owner/admin 삭제도 유지
--   · moim_delete_my_account(): 본인 데이터 정리 후 계정 삭제(전체관리자는 불가)
-- 실행 순서: ... room_manage.sql 이후 (moim_is_room_owner/moim_is_admin 필요)
-- =============================================================================

-- 1) 방 나가기: 본인은 자기 멤버십을 삭제할 수 있음 (+ 방 생성자·관리자도 삭제 가능)
DROP POLICY IF EXISTS "room_members_delete_owner_admin" ON public.room_members;
DROP POLICY IF EXISTS "room_members_delete_self_owner_admin" ON public.room_members;
CREATE POLICY "room_members_delete_self_owner_admin"
  ON public.room_members FOR DELETE TO authenticated
  USING (
    user_id = auth.uid()
    OR public.moim_is_room_owner(room_members.room_id)
    OR public.moim_is_admin()
  );

-- 2) 회원 탈퇴: 본인 데이터 정리 후 계정 삭제. 전체관리자(superadmin)는 불가.
CREATE OR REPLACE FUNCTION public.moim_delete_my_account()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE uid uuid := auth.uid();
BEGIN
  IF uid IS NULL THEN RETURN; END IF;
  IF EXISTS (SELECT 1 FROM public.profiles WHERE id = uid AND role = 'superadmin') THEN
    RAISE EXCEPTION '전체관리자는 탈퇴할 수 없습니다.';
  END IF;
  UPDATE public.ward_status SET updated_by = NULL WHERE updated_by = uid;
  DELETE FROM public.messages        WHERE sender_id   = uid;
  DELETE FROM public.room_files       WHERE uploaded_by = uid;
  DELETE FROM public.calendar_events  WHERE owner_id    = uid;
  DELETE FROM public.profiles         WHERE id = uid;   -- room_members/reads/pins 는 CASCADE
  DELETE FROM auth.users              WHERE id = uid;
END $$;
GRANT EXECUTE ON FUNCTION public.moim_delete_my_account() TO authenticated;

NOTIFY pgrst, 'reload schema';
-- =============================================================================
