-- =============================================================================
-- account_reactivate.sql — 비활성(탈퇴) 계정 복구(재활성화) + 승인
--   · moim_reactivate_user(uuid): 전체관리자가 비활성 회원을 복구.
--     withdrawn=false, approved=true 로 되돌리고 로그인 차단(banned_until) 해제.
--     계정 UUID 가 그대로이므로 이전 메시지·자료·작성자 이름이 그대로 연결됨.
--     (방 재배정은 관리자 콘솔 '방 관리'에서 다시 초대)
-- 실행 순서: ... admin_console.sql 이후
-- =============================================================================

CREATE OR REPLACE FUNCTION public.moim_reactivate_user(p_user uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.moim_is_superadmin() THEN
    RAISE EXCEPTION '권한이 없습니다.';
  END IF;
  UPDATE public.profiles SET withdrawn = false, approved = true WHERE id = p_user;
  -- 로그인 차단 해제 (auth 스키마 — 실패해도 무시)
  BEGIN
    UPDATE auth.users SET banned_until = NULL WHERE id = p_user;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
END $$;
GRANT EXECUTE ON FUNCTION public.moim_reactivate_user(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
-- =============================================================================
