-- =============================================================================
-- BugReport 고정 방 — 승인·미탈퇴 전원이 구성원(가상 멤버십, read_tracking 과 동일)
-- 실행 순서: ... seed_rooms.sql → install.sql → room_create.sql → ... → (이 파일)
-- (기존 BigReport/bigreport 로 시드했으면 아래 UPDATE 로 이름·카테고리 보정)
-- =============================================================================

ALTER TYPE public.room_category ADD VALUE IF NOT EXISTS 'bugreport';

INSERT INTO public.rooms (id, name, category, post_policy, sort_order, default_view)
VALUES
  ('11111111-1111-1111-1111-111111110013', 'BugReport', 'bugreport', 'members', 3, NULL)
ON CONFLICT (id) DO UPDATE SET
  name        = EXCLUDED.name,
  category    = EXCLUDED.category,
  post_policy = EXCLUDED.post_policy,
  sort_order  = EXCLUDED.sort_order,
  default_view= EXCLUDED.default_view;

-- 이전 BigReport(bigreport) 시드 보정
UPDATE public.rooms
   SET name = 'BugReport', category = 'bugreport'
 WHERE id = '11111111-1111-1111-1111-111111110013'
    OR category::text IN ('bigreport', 'bugreport');

NOTIFY pgrst, 'reload schema';
