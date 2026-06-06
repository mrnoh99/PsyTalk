-- =============================================================================
-- message_reactions.sql — 메시지 답장(reply) + 이모지 리액션 (카톡식 길게누르기 메뉴)
--   · messages.reply_to: 답장 대상 메시지 id (삭제되면 NULL).
--   · message_reactions: (message_id, user_id, emoji) 쌍 유일. 누구나 추가/취소(본인 것만).
--   · moim_room_reactions(room): 방의 모든 리액션 한 번에 조회(메시지와 함께 로드).
-- 실행 순서: ... message_delete.sql 이후 (messages 존재 필요)
-- 실행: Supabase SQL Editor (1회)
-- =============================================================================

-- 1) 답장 대상
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS reply_to uuid
  REFERENCES public.messages(id) ON DELETE SET NULL;

-- 2) 리액션 테이블
CREATE TABLE IF NOT EXISTS public.message_reactions (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id uuid NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  emoji      text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (message_id, user_id, emoji)
);
CREATE INDEX IF NOT EXISTS message_reactions_message_idx ON public.message_reactions (message_id);

ALTER TABLE public.message_reactions ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, DELETE ON TABLE public.message_reactions TO authenticated;

-- 조회: 인증 사용자 전체(메시지 SELECT 정책과 동일하게 공개)
DROP POLICY IF EXISTS "reactions_select" ON public.message_reactions;
CREATE POLICY "reactions_select"
  ON public.message_reactions FOR SELECT TO authenticated USING (true);

-- 추가/취소: 본인 것만
DROP POLICY IF EXISTS "reactions_insert_self" ON public.message_reactions;
CREATE POLICY "reactions_insert_self"
  ON public.message_reactions FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "reactions_delete_self" ON public.message_reactions;
CREATE POLICY "reactions_delete_self"
  ON public.message_reactions FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- 3) 방의 모든 리액션 조회 (메시지 로드와 함께 한 번에)
CREATE OR REPLACE FUNCTION public.moim_room_reactions(p_room uuid)
RETURNS SETOF public.message_reactions
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT r.* FROM public.message_reactions r
  JOIN public.messages m ON m.id = r.message_id
  WHERE m.room_id = p_room;
$$;
GRANT EXECUTE ON FUNCTION public.moim_room_reactions(uuid) TO authenticated;

-- 4) Realtime (선택) — 앱은 메시지 폴링과 함께 리액션을 재조회하므로 필수는 아님
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.message_reactions;
EXCEPTION WHEN duplicate_object THEN NULL; WHEN undefined_object THEN NULL; END $$;

NOTIFY pgrst, 'reload schema';
-- =============================================================================
