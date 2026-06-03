-- =============================================================================
-- 기본 방 11개 시드 (요구사항 sort_order 1~11)
-- Supabase SQL Editor에서 install.sql 실행 후 Run
-- =============================================================================

INSERT INTO public.rooms (id, name, category, post_policy, sort_order, default_view)
VALUES
  ('11111111-1111-1111-1111-111111110001', '과 전체공지',       'notice',   'restricted', 1,  NULL),
  ('11111111-1111-1111-1111-111111110002', '진료 공지',         'notice',   'members',    2,  NULL),
  ('11111111-1111-1111-1111-111111110003', '교실·의국·심리실',  'group',    'members',    3,  NULL),
  ('11111111-1111-1111-1111-111111110004', '교실',              'group',    'members',    4,  NULL),
  ('11111111-1111-1111-1111-111111110005', '의국',              'group',    'members',    5,  NULL),
  ('11111111-1111-1111-1111-111111110006', '심리실',            'group',    'members',    6,  NULL),
  ('11111111-1111-1111-1111-111111110007', '병동',              'work',     'members',    7,  NULL),
  ('11111111-1111-1111-1111-111111110008', '외래',              'work',     'members',    8,  NULL),
  ('11111111-1111-1111-1111-111111110009', '연구실 1',          'research', 'members',    9,  NULL),
  ('11111111-1111-1111-1111-111111110010', '연구실 2',          'research', 'members',    10, NULL),
  ('11111111-1111-1111-1111-111111110011', '연구실 3',          'research', 'members',    11, NULL)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  category = EXCLUDED.category,
  post_policy = EXCLUDED.post_policy,
  sort_order = EXCLUDED.sort_order,
  default_view = EXCLUDED.default_view;

-- 주간 학술활동 등 default_view 예시 (방이 이미 있으면 수동 적용):
-- UPDATE public.rooms SET default_view = 'week'
-- WHERE name = '주간 학술활동' OR sort_order = 2;

NOTIFY pgrst, 'reload schema';
