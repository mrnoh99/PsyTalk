-- protect_superadmin_password.sql
-- ─────────────────────────────────────────────────────────────────────────────
-- 전체관리자(superadmin, 고정: jsnoh@ajou.ac.kr) 의 비밀번호를 **변경 불가**로 보호.
--   - 웹/앱의 비밀번호 재설정·변경(updateUser) 또는 어떤 경로로든
--     auth.users 의 비밀번호(encrypted_password)가 바뀌려 하면 차단한다.
--   - 비밀번호 외의 정상 업데이트(last_sign_in_at, 토큰 등)는 그대로 허용.
--   - 클라이언트(웹 index.html)에도 1차 차단이 있으나, API 직접 호출까지 막기 위한 서버측 방어.
--
-- 참고: 만약 전체관리자 본인이 의도적으로 비밀번호를 바꿔야 한다면
--   이 트리거를 잠시 끄고( DROP TRIGGER ) 변경 후 다시 생성하면 된다.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.block_superadmin_password_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- 대상 계정이 전체관리자이고, 비밀번호 해시가 실제로 바뀌는 경우에만 차단
  IF lower(coalesce(OLD.email,'')) = 'jsnoh@ajou.ac.kr'
     AND NEW.encrypted_password IS DISTINCT FROM OLD.encrypted_password THEN
    RAISE EXCEPTION '전체관리자 계정의 비밀번호는 변경할 수 없습니다.';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_block_superadmin_password ON auth.users;
CREATE TRIGGER trg_block_superadmin_password
  BEFORE UPDATE ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.block_superadmin_password_change();
