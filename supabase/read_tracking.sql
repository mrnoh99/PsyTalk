-- =============================================================================
-- read_tracking.sql — 읽음 추적
--   #1 안읽은 메시지가 있는 방 표시(방별 안읽은 수)
--   #2 메시지별 '안읽은 사람 수' (방원 중 보낸이 제외; superadmin 은 방원일 때만 포함)
--   · room_reads(room_id, user_id, last_read_at): 사용자가 방을 본 마지막 시각
--   · 모임방 회원 = room_members / 기본방 회원 = 승인된 전원
-- 실행: Supabase SQL Editor (install.sql·room_manage.sql 이후 1회)
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.room_reads (
  room_id      uuid NOT NULL REFERENCES public.rooms(id)    ON DELETE CASCADE,
  user_id      uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  last_read_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (room_id, user_id)
);
ALTER TABLE public.room_reads ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE ON public.room_reads TO authenticated;

-- 조회: 인증 사용자 전체(메시지별 안읽은 수 계산에 필요). 갱신은 본인 것만.
DROP POLICY IF EXISTS "room_reads_select" ON public.room_reads;
CREATE POLICY "room_reads_select" ON public.room_reads
  FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "room_reads_insert_own" ON public.room_reads;
CREATE POLICY "room_reads_insert_own" ON public.room_reads
  FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
DROP POLICY IF EXISTS "room_reads_update_own" ON public.room_reads;
CREATE POLICY "room_reads_update_own" ON public.room_reads
  FOR UPDATE TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- 방 회원 집합: 모임방(custom)=room_members, 기본방=승인된 전원
CREATE OR REPLACE FUNCTION public.moim_room_member_ids(p_room uuid)
RETURNS TABLE(user_id uuid)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT rm.user_id FROM public.room_members rm
    JOIN public.rooms r ON r.id = rm.room_id
   WHERE rm.room_id = p_room AND r.category = 'custom'
  UNION
  SELECT p.id FROM public.profiles p
   WHERE p.approved = true
     AND EXISTS (SELECT 1 FROM public.rooms r WHERE r.id = p_room AND r.category <> 'custom');
$$;

-- #1 현재 사용자의 방별 안읽은 메시지 수 (본인이 보낸 것 제외)
CREATE OR REPLACE FUNCTION public.moim_unread_counts()
RETURNS TABLE(room_id uuid, cnt bigint)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT m.room_id, count(*)
  FROM public.messages m
  LEFT JOIN public.room_reads r ON r.room_id = m.room_id AND r.user_id = auth.uid()
  WHERE m.sender_id <> auth.uid()
    AND (r.last_read_at IS NULL OR m.created_at > r.last_read_at)
  GROUP BY m.room_id;
$$;

-- #2 방의 메시지별 '안읽은 사람 수'
CREATE OR REPLACE FUNCTION public.moim_message_unread_counts(p_room uuid)
RETURNS TABLE(message_id uuid, unread int)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT m.id,
    (SELECT count(*)::int
       FROM public.moim_room_member_ids(p_room) mem
       LEFT JOIN public.room_reads rr ON rr.room_id = p_room AND rr.user_id = mem.user_id
      WHERE mem.user_id <> m.sender_id
        AND (rr.last_read_at IS NULL OR rr.last_read_at < m.created_at))
  FROM public.messages m
  WHERE m.room_id = p_room;
$$;

-- 읽음 표시 갱신(현재 사용자) — 방을 볼 때 호출
CREATE OR REPLACE FUNCTION public.moim_mark_read(p_room uuid)
RETURNS void
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  INSERT INTO public.room_reads(room_id, user_id, last_read_at)
  VALUES (p_room, auth.uid(), now())
  ON CONFLICT (room_id, user_id) DO UPDATE SET last_read_at = now();
$$;

GRANT EXECUTE ON FUNCTION public.moim_room_member_ids(uuid)         TO authenticated;
GRANT EXECUTE ON FUNCTION public.moim_unread_counts()              TO authenticated;
GRANT EXECUTE ON FUNCTION public.moim_message_unread_counts(uuid)  TO authenticated;
GRANT EXECUTE ON FUNCTION public.moim_mark_read(uuid)             TO authenticated;

-- Realtime (방목록 배지·메시지수 빠른 갱신)
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.room_reads;
EXCEPTION WHEN duplicate_object THEN NULL; WHEN others THEN NULL; END $$;

NOTIFY pgrst, 'reload schema';
-- =============================================================================
