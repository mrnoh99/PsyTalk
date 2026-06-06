-- =============================================================================
-- profile_member_type.sql — 내정보에서 직군(member_type) 변경 허용
-- 실행 순서: ... profile_edit.sql → (이 파일)
-- moim_update_my_profile 에 p_member_type 추가 (본인만, 허용 13직군만).
-- ※ 3인자 구버전(profile_edit.sql)이 남아 있으면 PostgREST 가 잘못 매칭할 수 있어 먼저 제거.
-- =============================================================================

DROP FUNCTION IF EXISTS public.moim_update_my_profile(text, text, text);

CREATE OR REPLACE FUNCTION public.moim_update_my_profile(
  p_intro        text DEFAULT NULL,
  p_avatar_url   text DEFAULT NULL,
  p_color        text DEFAULT NULL,
  p_member_type  text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  mt_udt text;
  mt     text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION '로그인이 필요합니다.';
  END IF;

  mt := NULLIF(trim(p_member_type), '');
  IF mt IS NOT NULL AND mt NOT IN (
    '교실','의국','심리실','연구실','PA','간호사','SW','보조원',
    '생명사랑','비서','의국동문','심리실 동문','기타'
  ) THEN
    RAISE EXCEPTION '허용되지 않은 직군입니다.';
  END IF;

  SELECT udt_name INTO mt_udt
  FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'member_type';

  IF mt IS NOT NULL AND EXISTS (
    SELECT 1 FROM pg_type t JOIN pg_namespace n ON t.typnamespace = n.oid
    WHERE n.nspname = 'public' AND t.typname = mt_udt AND t.typtype = 'e'
  ) THEN
    EXECUTE format(
      'UPDATE public.profiles SET intro = $1, avatar_url = $2, color = $3, member_type = $4::%I WHERE id = $5',
      mt_udt
    ) USING p_intro, p_avatar_url, p_color, mt, auth.uid();
  ELSE
    UPDATE public.profiles
       SET intro      = p_intro,
           avatar_url = p_avatar_url,
           color      = p_color,
           member_type = COALESCE(mt, member_type)
     WHERE id = auth.uid();
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.moim_update_my_profile(text, text, text, text) TO authenticated;

NOTIFY pgrst, 'reload schema';
