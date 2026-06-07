-- 당직표: 전공의 외래(최대 2인) + 편집 권한(교실·의국·비서)
ALTER TABLE public.ward_duty
  ADD COLUMN IF NOT EXISTS resident_outpatient_1 text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS resident_outpatient_2 text NOT NULL DEFAULT '';

DROP POLICY IF EXISTS "ward_duty_insert" ON public.ward_duty;
CREATE POLICY "ward_duty_insert"
  ON public.ward_duty FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid()
                 AND (p.role IN ('superadmin','admin') OR p.member_type IN ('교실','의국','비서'))));

DROP POLICY IF EXISTS "ward_duty_update" ON public.ward_duty;
CREATE POLICY "ward_duty_update"
  ON public.ward_duty FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid()
                 AND (p.role IN ('superadmin','admin') OR p.member_type IN ('교실','의국','비서'))))
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid()
                 AND (p.role IN ('superadmin','admin') OR p.member_type IN ('교실','의국','비서'))));

DROP POLICY IF EXISTS "ward_duty_delete" ON public.ward_duty;
CREATE POLICY "ward_duty_delete"
  ON public.ward_duty FOR DELETE TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid()
                 AND (p.role IN ('superadmin','admin') OR p.member_type IN ('교실','의국','비서'))));

NOTIFY pgrst, 'reload schema';
