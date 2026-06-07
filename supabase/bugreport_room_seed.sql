-- =============================================================================
-- BugReport 고정 방 시드 — Supabase SQL Editor 에서 이 파일 전체를 Run (한 번)
-- ※ 'bugreport' enum 은 사용하지 않습니다. category='notice' (seed_rooms 와 동일).
-- ※ 앱은 방 id 11111111-1111-1111-1111-111111110013 로 BugReport 를 식별합니다.
-- =============================================================================

INSERT INTO public.rooms (id, name, category, post_policy, sort_order, default_view)
VALUES
  ('11111111-1111-1111-1111-111111110013', 'BugReport', 'notice', 'members', 3, NULL)
ON CONFLICT (id) DO UPDATE SET
  name        = EXCLUDED.name,
  category    = EXCLUDED.category,
  post_policy = EXCLUDED.post_policy,
  sort_order  = EXCLUDED.sort_order,
  default_view= EXCLUDED.default_view;

NOTIFY pgrst, 'reload schema';
