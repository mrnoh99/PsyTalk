-- =============================================================================
-- room_appearance.sql — 방표식(아바타) 색상·사진 커스터마이즈
--   · rooms.color: 방표식 배경색 (hex, 예 '#4A6FA5'). NULL = 카테고리 기본색.
--   · rooms.icon_url: 방표식 사진 공개 URL (public room-files 버킷). NULL = 색+이름.
--   수정 권한은 기존 rooms UPDATE 정책(생성자/관리자, room_create.sql)으로 강제됨.
-- 실행 순서: ... room_create.sql 이후 (rooms_update_owner_admin 필요)
-- =============================================================================

ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS color    text;
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS icon_url text;

NOTIFY pgrst, 'reload schema';
-- =============================================================================
