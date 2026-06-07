-- =============================================================================
-- BugReport 고정 방 시드 (한 번에 Run)
-- category 는 기존 enum 값 'group' 사용 — 'bugreport' enum 추가 불필요(Supabase enum 커밋 이슈 회피).
-- 앱은 방 id(11111111-…-0013) 로 BugReport 방을 식별합니다.
-- 승인·미탈퇴 전원 구성원 = read_tracking 의 기본방 가상 멤버십과 동일.
-- =============================================================================

INSERT INTO public.rooms (id, name, category, post_policy, sort_order, default_view)
VALUES
  ('11111111-1111-1111-1111-111111110013', 'BugReport', 'group', 'members', 3, NULL)
ON CONFLICT (id) DO UPDATE SET
  name        = EXCLUDED.name,
  category    = EXCLUDED.category,
  post_policy = EXCLUDED.post_policy,
  sort_order  = EXCLUDED.sort_order,
  default_view= EXCLUDED.default_view;

-- 이전 시드(BigReport/bigreport/bugreport 카테고리) 보정
UPDATE public.rooms
   SET name = 'BugReport', category = 'group'
 WHERE id = '11111111-1111-1111-1111-111111110013';

NOTIFY pgrst, 'reload schema';
