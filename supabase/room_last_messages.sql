-- =============================================================================
-- room_last_messages.sql — 방 목록의 '마지막 메시지' (미리보기 + 시각)
--   각 방의 가장 최근 메시지 1건. 방 목록 행에 표시.
-- 실행: Supabase SQL Editor (install.sql 이후 1회)
-- =============================================================================
CREATE OR REPLACE FUNCTION public.moim_room_last_messages()
RETURNS TABLE(room_id uuid, content text, type text, attachment_name text, created_at timestamptz)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT DISTINCT ON (m.room_id)
         m.room_id, m.content, m.type, m.attachment_name, m.created_at
  FROM public.messages m
  ORDER BY m.room_id, m.created_at DESC;
$$;
GRANT EXECUTE ON FUNCTION public.moim_room_last_messages() TO authenticated;

NOTIFY pgrst, 'reload schema';
-- =============================================================================
