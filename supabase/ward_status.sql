-- =============================================================================
-- 병실 잔여 현황 (사용자가 직접 기재 — 앱에서 편집, 모두에게 공유)
-- 단일 행(id=1)에 자유 텍스트로 저장. schema_extension.sql 이후 실행.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.ward_status (
  id int PRIMARY KEY DEFAULT 1,
  content text NOT NULL DEFAULT '',
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid REFERENCES public.profiles(id),
  CONSTRAINT ward_status_singleton CHECK (id = 1)
);

-- 초기값(예시) — 언제든 앱에서 편집 가능
INSERT INTO public.ward_status (id, content)
VALUES (1,
'- 남자
다인실: 0자리 (1자리 EICU 전과예정)
3인실(APICU): 0자리

- 여자
다인실: 0자리 (여자 1자리 퇴원예정)
3인실(APICU): 1자리
2인실(APICU): 0자리')
ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.ward_status ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE ON public.ward_status TO authenticated;

-- 모든 인증 사용자 조회
DROP POLICY IF EXISTS "ward_status_select" ON public.ward_status;
CREATE POLICY "ward_status_select"
  ON public.ward_status FOR SELECT TO authenticated USING (true);

-- 인증 사용자 편집 (병동 운영 정보 — 필요 시 admin 으로 제한 가능)
DROP POLICY IF EXISTS "ward_status_update" ON public.ward_status;
CREATE POLICY "ward_status_update"
  ON public.ward_status FOR UPDATE TO authenticated USING (true);

DROP POLICY IF EXISTS "ward_status_insert" ON public.ward_status;
CREATE POLICY "ward_status_insert"
  ON public.ward_status FOR INSERT TO authenticated WITH CHECK (true);

NOTIFY pgrst, 'reload schema';
