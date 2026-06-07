-- =============================================================================
-- 당직표 (날짜별 교수 낮당직 · 전공의 밤당직)
-- ward_status.sql 이후 실행. 편집 권한은 ward_status 와 동일.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.ward_duty (
  duty_date date PRIMARY KEY,
  prof_day text NOT NULL DEFAULT '',
  resident_day text NOT NULL DEFAULT '',
  resident_night text NOT NULL DEFAULT '',
  is_holiday boolean NOT NULL DEFAULT false,
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid REFERENCES public.profiles(id)
);

ALTER TABLE public.ward_duty ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.ward_duty TO authenticated;

DROP POLICY IF EXISTS "ward_duty_select" ON public.ward_duty;
CREATE POLICY "ward_duty_select"
  ON public.ward_duty FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "ward_duty_insert" ON public.ward_duty;
CREATE POLICY "ward_duty_insert"
  ON public.ward_duty FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid()
                 AND (p.role IN ('superadmin','admin') OR p.member_type IN ('교실','의국','간호사'))));

DROP POLICY IF EXISTS "ward_duty_update" ON public.ward_duty;
CREATE POLICY "ward_duty_update"
  ON public.ward_duty FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid()
                 AND (p.role IN ('superadmin','admin') OR p.member_type IN ('교실','의국','간호사'))))
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid()
                 AND (p.role IN ('superadmin','admin') OR p.member_type IN ('교실','의국','간호사'))));

DROP POLICY IF EXISTS "ward_duty_delete" ON public.ward_duty;
CREATE POLICY "ward_duty_delete"
  ON public.ward_duty FOR DELETE TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid()
                 AND (p.role IN ('superadmin','admin') OR p.member_type IN ('교실','의국','간호사'))));

NOTIFY pgrst, 'reload schema';
