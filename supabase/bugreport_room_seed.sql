-- =============================================================================
-- BugReport 2단계 — 고정 방 시드 (승인·미탈퇴 전원 구성원, read_tracking 가상 멤버십)
-- 선행: bugreport_room.sql (enum 'bugreport' 추가) 를 먼저 Run 했는지 확인.
-- (기존 BigReport/bigreport 로 넣었으면 아래 UPDATE 로 이름·카테고리 보정)
-- =============================================================================

INSERT INTO public.rooms (id, name, category, post_policy, sort_order, default_view)
VALUES
  ('11111111-1111-1111-1111-111111110013', 'BugReport', 'bugreport'::public.room_category, 'members', 3, NULL)
ON CONFLICT (id) DO UPDATE SET
  name        = EXCLUDED.name,
  category    = EXCLUDED.category,
  post_policy = EXCLUDED.post_policy,
  sort_order  = EXCLUDED.sort_order,
  default_view= EXCLUDED.default_view;

-- 이전 BigReport(bigreport) 시드 보정
UPDATE public.rooms
   SET name = 'BugReport',
       category = 'bugreport'::public.room_category
 WHERE id = '11111111-1111-1111-1111-111111110013'
    OR category::text IN ('bigreport', 'bugreport');

NOTIFY pgrst, 'reload schema';
