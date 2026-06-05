-- =============================================================================
-- admin_console.sql — 관리자 콘솔 개편(가입승인·회원관리·방관리) +
--   '탈퇴 = 비활성(글·자료는 보존)'
--   · profiles.withdrawn: 탈퇴(비활성) 표시. 계정 로그인은 막되 글/자료/이름은 보존.
--   · moim_approve_user(uuid): 가입 승인(관리자·전체관리자). 신규 가입자 approved=true.
--   · moim_delete_my_account(): 본인 탈퇴 = 비활성(글·자료 보존, 전체관리자 불가).
--   · moim_admin_withdraw(uuid): 전체관리자가 회원 탈퇴(비활성).
-- 실행 순서: ... leave_account.sql 이후 (moim_is_admin/moim_is_superadmin 필요)
-- 실행: Supabase SQL Editor (1회). 이미 leave_account.sql 을 실행했어도 다시 받아도 됨.
-- =============================================================================

-- 1) 탈퇴(비활성) 표시 컬럼 — 기록은 남기고 활동만 막음
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS withdrawn boolean NOT NULL DEFAULT false;

-- 2) 가입 승인 RPC — 관리자/전체관리자가 신규 가입자 승인.
--    (profiles UPDATE 정책은 전체관리자 전용이라, 관리자도 승인할 수 있게 RPC 로 우회)
CREATE OR REPLACE FUNCTION public.moim_approve_user(p_user uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.moim_is_admin() THEN
    RAISE EXCEPTION '권한이 없습니다.';
  END IF;
  UPDATE public.profiles
     SET approved = true
   WHERE id = p_user AND role <> 'superadmin' AND withdrawn = false;
END $$;
GRANT EXECUTE ON FUNCTION public.moim_approve_user(uuid) TO authenticated;

-- 3) 공통 헬퍼: 한 사용자를 탈퇴(비활성) 처리.
--    글·자료·일정은 보존(작성자 이름 계속 표시), 방·고정만 정리, 로그인 차단.
--    내부 헬퍼이므로 authenticated 에 GRANT 하지 않음(외부에서 임의 호출 차단).
--    SECURITY DEFINER 함수 안에서 PERFORM 으로만 호출됨.
CREATE OR REPLACE FUNCTION public.moim_withdraw_user(p_user uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF p_user IS NULL THEN RETURN; END IF;
  IF EXISTS (SELECT 1 FROM public.profiles WHERE id = p_user AND role = 'superadmin') THEN
    RAISE EXCEPTION '전체관리자는 탈퇴할 수 없습니다.';
  END IF;
  -- 방·고정 등 활동 데이터만 정리 (메시지·자료·일정은 보존)
  DELETE FROM public.room_members WHERE user_id = p_user;
  DELETE FROM public.room_pins    WHERE user_id = p_user;
  -- 프로필은 남기되 비활성 표시 → 옛 글/자료의 작성자 이름이 계속 표시됨
  UPDATE public.profiles SET withdrawn = true, approved = false WHERE id = p_user;
  -- 로그인 차단 + 기존 세션 무효화 (auth 스키마 — 버전 차이로 실패해도 무시)
  BEGIN
    UPDATE auth.users SET banned_until = now() + interval '100 years' WHERE id = p_user;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
  BEGIN
    DELETE FROM auth.refresh_tokens WHERE user_id = p_user::text;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
END $$;
-- 내부 헬퍼: PUBLIC 기본 EXECUTE 회수 → 외부(PostgREST)에서 직접 호출 불가.
--   (아래 래퍼 함수들이 SECURITY DEFINER 로 내부에서만 PERFORM 한다)
REVOKE EXECUTE ON FUNCTION public.moim_withdraw_user(uuid) FROM PUBLIC;

-- 4) 본인 탈퇴 (전체관리자 불가) — 글·자료 보존
CREATE OR REPLACE FUNCTION public.moim_delete_my_account()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM public.moim_withdraw_user(auth.uid());
END $$;
GRANT EXECUTE ON FUNCTION public.moim_delete_my_account() TO authenticated;

-- 5) 전체관리자가 회원 탈퇴(비활성) — 회원관리 화면의 '탈퇴' 버튼
CREATE OR REPLACE FUNCTION public.moim_admin_withdraw(p_user uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.moim_is_superadmin() THEN
    RAISE EXCEPTION '권한이 없습니다.';
  END IF;
  PERFORM public.moim_withdraw_user(p_user);
END $$;
GRANT EXECUTE ON FUNCTION public.moim_admin_withdraw(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';

-- 확인:
--   select name, role, approved, withdrawn from public.profiles order by withdrawn, approved, name;
-- =============================================================================
