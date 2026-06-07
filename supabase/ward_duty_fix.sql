-- =============================================================================
-- 당직표 DB 수정 (Android/iOS/Web 입력·수정 실패 시)
-- Supabase → SQL Editor 에서 이 파일 전체를 한 번 실행하세요.
--
-- 원인: 초기 ward_duty.sql(교원+방당직만)만 실행한 경우
--   · resident_day / resident_outpatient_1 / resident_outpatient_2 컬럼 없음 → 저장 실패
--   · RLS가 간호사 기준(비서 제외) 또는 UPDATE USING/WITH CHECK 불일치 → 수정 실패
--
-- ward_duty 테이블이 없으면 먼저 ward_duty.sql 을 실행한 뒤 이 파일을 실행하세요.
-- =============================================================================

ALTER TABLE public.ward_duty
  ADD COLUMN IF NOT EXISTS resident_day text NOT NULL DEFAULT '',
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
