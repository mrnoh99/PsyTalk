-- =============================================================================
-- BugReport 1단계 — room_category enum 에 'bugreport' 추가
-- PostgreSQL: 새 enum 값은 커밋된 뒤에만 사용 가능 → 이 파일만 먼저 Run 한 번.
-- 다음: bugreport_room_seed.sql 실행
-- 실행 순서: ... direct_messages.sql 이후 (room_category enum 존재)
-- =============================================================================

ALTER TYPE public.room_category ADD VALUE IF NOT EXISTS 'bugreport';

NOTIFY pgrst, 'reload schema';
