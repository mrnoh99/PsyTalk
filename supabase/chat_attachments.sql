-- =============================================================================
-- chat_attachments.sql — 채팅 메시지 첨부(사진/파일) + 방 구성원만 다운로드
--   · messages 에 첨부 컬럼 추가 (type / attachment_url / attachment_name)
--   · 채팅 첨부는 비공개 버킷 'chat-files' 에 저장 (자료실 'room-files' 와 분리)
--   · 다운로드/업로드는 '그 방을 볼 수 있는 사람'(=방 가시성 규칙)만 허용
--   · attachment_url 에는 공개 URL 이 아니라 스토리지 'path'(roomId/...) 를 저장.
--     클라이언트가 다운로드 시 createSignedUrl 로 서명 URL 을 발급 → 비구성원은 발급 불가.
-- 실행: Supabase SQL Editor (room_manage.sql 이후 1회)
-- =============================================================================

-- 1) messages 첨부 컬럼
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS type            text NOT NULL DEFAULT 'text';  -- text|image|file
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS attachment_url  text;   -- chat-files 의 path (roomId/...)
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS attachment_name text;

-- 2) 비공개 버킷 생성
INSERT INTO storage.buckets (id, name, public)
VALUES ('chat-files', 'chat-files', false)
ON CONFLICT (id) DO UPDATE SET public = false;

-- 3) 다운로드(SELECT): 그 방을 볼 수 있는 사람만 (방 가시성 규칙과 동일) + 관리자
--    path 첫 폴더 = room_id
DROP POLICY IF EXISTS "chat_files_read" ON storage.objects;
CREATE POLICY "chat_files_read"
  ON storage.objects FOR SELECT TO authenticated
  USING (
    bucket_id = 'chat-files'
    AND (
      EXISTS (
        SELECT 1 FROM public.rooms r
        WHERE r.id = ((storage.foldername(name))[1])::uuid
          AND (
            r.category <> 'custom'                          -- 기본 방(전체공지·학술활동): 전원
            OR r.created_by = auth.uid()                    -- 모임방: 생성자
            OR r.id IN (SELECT public.moim_my_room_ids())   -- 모임방: 구성원
          )
      )
      OR public.moim_is_admin()                             -- 관리자/전체관리자
    )
  );

-- 4) 업로드(INSERT): 같은 방 가시성 규칙
DROP POLICY IF EXISTS "chat_files_upload" ON storage.objects;
CREATE POLICY "chat_files_upload"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'chat-files'
    AND (
      EXISTS (
        SELECT 1 FROM public.rooms r
        WHERE r.id = ((storage.foldername(name))[1])::uuid
          AND (
            r.category <> 'custom'
            OR r.created_by = auth.uid()
            OR r.id IN (SELECT public.moim_my_room_ids())
          )
      )
      OR public.moim_is_admin()
    )
  );

-- 5) 삭제(DELETE): 올린 사람 또는 관리자
DROP POLICY IF EXISTS "chat_files_delete" ON storage.objects;
CREATE POLICY "chat_files_delete"
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'chat-files'
    AND (owner = auth.uid() OR public.moim_is_admin())
  );

NOTIFY pgrst, 'reload schema';

-- 확인: 비구성원이 createSignedUrl 호출 시 권한 오류로 URL 발급 불가 → 다운로드 차단됨.
-- =============================================================================
