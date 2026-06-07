-- =============================================================================
-- secretary_perms.sql — 비서(member_type='비서')에게 가입 승인 권한 부여
-- -----------------------------------------------------------------------------
--   요구사항: 전체공지 작성 · 당직표 작성 · 가입 승인을
--             superadmin · admin 외에 '비서' 직군도 할 수 있어야 함.
--     · 당직표 작성  : 이미 ward_duty.sql 에서 '비서' 허용됨 (추가 작업 없음)
--     · 전체공지 작성: messages INSERT 는 클라이언트(canPost)에서 정책 적용
--                      (앱/웹 코드에서 '비서' 허용 — 별도 SQL 불필요)
--     · 가입 승인    : moim_approve_user() 가 admin 만 허용 → '비서'도 허용하도록 갱신
--
--   실행 순서: admin_console.sql · ward_calendar_perms.sql 이후 (1회 실행)
--   실행: Supabase 대시보드 → SQL Editor → Run
-- =============================================================================

-- 가입 승인 RPC — admin/superadmin 또는 직군 '비서' 가 신규 가입자 승인 가능.
CREATE OR REPLACE FUNCTION public.moim_approve_user(p_user uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT (public.moim_is_admin() OR public.moim_my_member_type() = '비서') THEN
    RAISE EXCEPTION '권한이 없습니다.';
  END IF;
  UPDATE public.profiles
     SET approved = true
   WHERE id = p_user AND role <> 'superadmin' AND withdrawn = false;
END $$;

GRANT EXECUTE ON FUNCTION public.moim_approve_user(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
-- =============================================================================
