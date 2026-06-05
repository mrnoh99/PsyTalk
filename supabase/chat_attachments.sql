-- =============================================================================
-- chat_attachments.sql — 채팅 메시지 첨부(사진/파일) 컬럼
--   · messages 에 type / attachment_url(공개 URL) / attachment_name 추가
--   · 파일은 기존 공개 'room-files' 버킷에 저장 (storage_setup.sql 정책 그대로 사용)
--     → 누구나 URL 로 다운로드 가능 (방 제한 없음)
-- 실행: Supabase SQL Editor (storage_setup.sql 이후 1회)
-- =============================================================================

ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS type            text NOT NULL DEFAULT 'text';  -- text|image|file
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS attachment_url  text;   -- room-files 공개 URL
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS attachment_name text;

NOTIFY pgrst, 'reload schema';

-- (참고) 이전에 만든 비공개 'chat-files' 버킷이 있다면 더 이상 사용하지 않습니다(있어도 무해).
-- =============================================================================
