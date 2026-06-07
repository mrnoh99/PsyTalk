-- 당직표: 전공의 낮당직 컬럼 추가 (기존 ward_duty.sql 실행 후)
ALTER TABLE public.ward_duty
  ADD COLUMN IF NOT EXISTS resident_day text NOT NULL DEFAULT '';

NOTIFY pgrst, 'reload schema';
