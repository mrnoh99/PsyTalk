-- =============================================================================
-- chat_attachments.sql — 채팅 메시지 첨부(사진/파일) 지원
--   messages 에 첨부 컬럼 추가. 파일은 기존 'room-files' 스토리지 버킷 재사용.
--   type: 'text'(기본) | 'image' | 'file'
-- 실행: Supabase SQL Editor (storage_setup.sql 이후 아무 때나 1회)
-- =============================================================================

-- type 컬럼 보장 (이미 있으면 무시)
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS type text NOT NULL DEFAULT 'text';
-- 첨부 메타
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS attachment_url  text;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS attachment_name text;

NOTIFY pgrst, 'reload schema';

-- 참고: 스토리지 업로드/다운로드 정책은 storage_setup.sql 의 'room-files' 버킷 정책을
--       그대로 사용합니다(인증 사용자 업로드, 공개 다운로드). 별도 추가 불필요.
-- =============================================================================
