-- =============================================================================
-- 잔여 병실 현황 (사용자가 직접 기재 — 앱에서 편집, 모두에게 공유)
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

-- 편집/추가: 관리자 또는 직군(교실·의국·간호사)만. (열린 USING(true) 금지 — 연구실 등 차단)
DROP POLICY IF EXISTS "ward_status_update" ON public.ward_status;
CREATE POLICY "ward_status_update"
  ON public.ward_status FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid()
                 AND (p.role IN ('superadmin','admin') OR p.member_type IN ('교실','의국','간호사'))))
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid()
                 AND (p.role IN ('superadmin','admin') OR p.member_type IN ('교실','의국','간호사'))));

DROP POLICY IF EXISTS "ward_status_insert" ON public.ward_status;
CREATE POLICY "ward_status_insert"
  ON public.ward_status FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid()
                 AND (p.role IN ('superadmin','admin') OR p.member_type IN ('교실','의국','간호사'))));

NOTIFY pgrst, 'reload schema';
