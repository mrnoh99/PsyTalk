-- =============================================================================
-- message_delete.sql — 채팅 메시지(텍스트/사진/파일) 삭제 권한
--   · 본인이 쓴 메시지는 본인이 삭제 가능 (관리자/전체관리자도 가능)
--   · 첨부(사진/파일)도 메시지 행을 지우면 채팅에서 사라짐
-- 실행: Supabase SQL Editor (install.sql 이후 1회)
-- =============================================================================

GRANT DELETE ON public.messages TO authenticated;

DROP POLICY IF EXISTS "messages_delete_own" ON public.messages;
CREATE POLICY "messages_delete_own"
  ON public.messages FOR DELETE TO authenticated
  USING (
    sender_id = auth.uid()        -- 본인이 쓴 메시지
    OR public.moim_is_admin()     -- 관리자/전체관리자
  );

NOTIFY pgrst, 'reload schema';
-- =============================================================================
