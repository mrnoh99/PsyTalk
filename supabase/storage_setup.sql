-- =============================================================================
-- 자료실 파일 스토리지 설정 (Supabase Storage)
-- 캘린더 첨부 + 자료실 직접 업로드 파일을 'room-files' 버킷에 저장
-- Supabase SQL Editor 에서 schema_extension.sql 실행 후 Run
-- (또는 대시보드 Storage 에서 동일하게 버킷을 만들어도 됩니다.)
-- =============================================================================

-- 1) 버킷 생성 (public = 다운로드 URL 공개)
INSERT INTO storage.buckets (id, name, public)
VALUES ('room-files', 'room-files', true)
ON CONFLICT (id) DO UPDATE SET public = EXCLUDED.public;

-- 2) 오브젝트 정책 (인증 사용자 업로드 / 공개 다운로드)
DROP POLICY IF EXISTS "room_files_read" ON storage.objects;
CREATE POLICY "room_files_read"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'room-files');

DROP POLICY IF EXISTS "room_files_upload" ON storage.objects;
CREATE POLICY "room_files_upload"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'room-files');

DROP POLICY IF EXISTS "room_files_modify" ON storage.objects;
CREATE POLICY "room_files_modify"
  ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id = 'room-files');

NOTIFY pgrst, 'reload schema';
