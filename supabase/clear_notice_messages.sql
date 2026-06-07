-- =============================================================================
-- clear_notice_messages.sql — 과 전체공지 방의 모든 공지(메시지) 삭제
-- 실행: Supabase 대시보드 → SQL Editor → Run
--   · 대상 방: 전체공지 (id 11111111-1111-1111-1111-111111110001)
--   · 메시지·리액션·답장 참조는 CASCADE/SET NULL 처리됨. 방 자체는 유지.
-- =============================================================================

DO $$
DECLARE
  v_room uuid := '11111111-1111-1111-1111-111111110001';
  v_before bigint;
  v_after bigint;
BEGIN
  SELECT count(*) INTO v_before FROM public.messages WHERE room_id = v_room;

  DELETE FROM public.messages WHERE room_id = v_room;

  SELECT count(*) INTO v_after FROM public.messages WHERE room_id = v_room;

  RAISE NOTICE '전체공지 메시지 삭제: %건 → %건 남음', v_before, v_after;
END $$;

NOTIFY pgrst, 'reload schema';
-- =============================================================================
