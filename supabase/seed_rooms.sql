-- =============================================================================
-- 기본 방 시드 — 전체공지 + 학술활동 2개만 (이름은 관리자가 앱에서 변경 가능)
-- 나머지 방은 사용자가 앱에서 직접 생성(모임방). install.sql 이후 Run.
-- =============================================================================

INSERT INTO public.rooms (id, name, category, post_policy, sort_order, default_view)
VALUES
  ('11111111-1111-1111-1111-111111110001', '전체공지', 'notice', 'restricted', 1, NULL),
  ('11111111-1111-1111-1111-111111110012', '학술활동', 'notice', 'members',    2, 'week')
ON CONFLICT (id) DO UPDATE SET
  name        = EXCLUDED.name,
  category    = EXCLUDED.category,
  post_policy = EXCLUDED.post_policy,
  sort_order  = EXCLUDED.sort_order,
  default_view= EXCLUDED.default_view;

NOTIFY pgrst, 'reload schema';
