-- =============================================================================
-- direct_messages.sql — 1:1 다이렉트 채팅(카톡 DM식)
-- 실행 순서: ... room_manage.sql 이후 (rooms/room_members RLS·헬퍼가 이미 있어야 함)
-- -----------------------------------------------------------------------------
-- DM = rooms 의 한 행( category='direct' ). 두 사람이 room_members 로 참여.
--   · name/dm_key = 두 사용자 UUID를 정렬해 합친 키 (a < b → 'a_b') → 쌍마다 유일.
--   · 표시 이름·아바타는 클라이언트에서 "상대방" 프로필로 계산(dm_key 파싱).
--   · 메시지/자료/일정 RLS 는 기존 그대로 사용(messages SELECT=true, INSERT=sender 본인).
--   · 생성·중복방지·양쪽 멤버십 보정은 RPC(moim_open_direct)로 처리(레이스/RLS 회피).
-- =============================================================================

-- DM 식별 키 (쌍마다 유일). 일반/모임방은 NULL.
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS dm_key text;
CREATE UNIQUE INDEX IF NOT EXISTS rooms_dm_key_unique
  ON public.rooms (dm_key) WHERE dm_key IS NOT NULL;

-- category 가 enum(room_category): 'direct' 값 추가 (이미 있으면 무시).
--   ※ 새 enum 값은 추가한 같은 트랜잭션 안에서 "사용"하면 오류(unsafe use)가 나므로,
--     아래 정책에서는 'direct' 비교를 category::text 로 처리(=enum 값 직접사용 회피)해 한 번에 실행돼도 안전.
--   ※ ALTER TYPE ADD VALUE 는 DO/함수 블록 안에서 못 쓰므로 최상위 문으로 실행.
ALTER TYPE public.room_category ADD VALUE IF NOT EXISTS 'direct';

-- 방 가시성 재정의: 기본 방=전체 / 모임방=구성원·생성자·관리자 / DM=구성원만(관리자도 콘솔엔 안 보임)
DROP POLICY IF EXISTS "rooms_select_visible" ON public.rooms;
CREATE POLICY "rooms_select_visible"
  ON public.rooms FOR SELECT TO authenticated
  USING (
    (category <> 'custom' AND category::text <> 'direct')           -- 기본 방(전체방·학술활동 등)
    OR (category = 'custom' AND (
          created_by = auth.uid()
          OR id IN (SELECT public.moim_my_room_ids())
          OR public.moim_is_admin()))
    OR (category::text = 'direct' AND id IN (SELECT public.moim_my_room_ids()))  -- DM 은 당사자만
  );

-- DM 열기(없으면 생성): 상대 user id 를 받아 방 id 반환. 양쪽 멤버십 보정.
CREATE OR REPLACE FUNCTION public.moim_open_direct(p_other uuid)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_me  uuid := auth.uid();
  v_a   uuid;
  v_b   uuid;
  v_key text;
  v_rid uuid;
BEGIN
  IF v_me IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.'; END IF;
  IF p_other IS NULL OR p_other = v_me THEN RAISE EXCEPTION '상대를 선택하세요.'; END IF;
  -- 상대가 실제 회원인지 확인
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_other) THEN
    RAISE EXCEPTION '존재하지 않는 회원입니다.';
  END IF;

  IF v_me < p_other THEN v_a := v_me; v_b := p_other; ELSE v_a := p_other; v_b := v_me; END IF;
  v_key := v_a || '_' || v_b;

  SELECT id INTO v_rid FROM public.rooms WHERE dm_key = v_key LIMIT 1;
  IF v_rid IS NULL THEN
    v_rid := gen_random_uuid();
    INSERT INTO public.rooms (id, name, category, post_policy, sort_order, created_by, dm_key)
      VALUES (v_rid, v_key, 'direct', 'members',
              floor(extract(epoch FROM now()))::int, v_me, v_key);
  END IF;

  -- 양쪽 멤버십 보정(한쪽이 나간 경우 포함)
  INSERT INTO public.room_members (room_id, user_id)
    VALUES (v_rid, v_a), (v_rid, v_b)
  ON CONFLICT DO NOTHING;

  RETURN v_rid;
END;
$$;

GRANT EXECUTE ON FUNCTION public.moim_open_direct(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
