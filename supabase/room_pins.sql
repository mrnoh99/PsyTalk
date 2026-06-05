-- =============================================================================
-- room_pins.sql — 방 순서 '고정(핀)' (개인별, 최대 5개)
--   · 각 사용자가 방 목록 상단에 고정할 방 5개와 순서를 정함.
--   · 핀이 아닌 방은 클라이언트에서 '최근 메시지 순'으로 정렬.
-- 실행: Supabase SQL Editor (install.sql 이후 1회)
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.room_pins (
  user_id  uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  room_id  uuid NOT NULL REFERENCES public.rooms(id)    ON DELETE CASCADE,
  position int  NOT NULL,
  PRIMARY KEY (user_id, room_id)
);
ALTER TABLE public.room_pins ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.room_pins TO authenticated;

-- 본인 것만 관리
DROP POLICY IF EXISTS "room_pins_select" ON public.room_pins;
CREATE POLICY "room_pins_select" ON public.room_pins FOR SELECT TO authenticated USING (user_id = auth.uid());
DROP POLICY IF EXISTS "room_pins_insert" ON public.room_pins;
CREATE POLICY "room_pins_insert" ON public.room_pins FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
DROP POLICY IF EXISTS "room_pins_update" ON public.room_pins;
CREATE POLICY "room_pins_update" ON public.room_pins FOR UPDATE TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
DROP POLICY IF EXISTS "room_pins_delete" ON public.room_pins;
CREATE POLICY "room_pins_delete" ON public.room_pins FOR DELETE TO authenticated USING (user_id = auth.uid());

-- 핀 목록 전체 교체 (순서 = 배열 순서, 최대 5개)
CREATE OR REPLACE FUNCTION public.moim_set_room_pins(p_rooms uuid[])
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  DELETE FROM public.room_pins WHERE user_id = auth.uid();
  INSERT INTO public.room_pins(user_id, room_id, position)
  SELECT auth.uid(), r, ord
  FROM unnest(p_rooms[1:5]) WITH ORDINALITY AS t(r, ord);
END $$;
GRANT EXECUTE ON FUNCTION public.moim_set_room_pins(uuid[]) TO authenticated;

NOTIFY pgrst, 'reload schema';
-- =============================================================================
