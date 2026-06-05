-- ============================================================
-- seed_dummy_members.sql — 테스트용 더미 회원 8명 생성 (직군별 1명)
-- ------------------------------------------------------------
-- 목적: 방 생성 시 "참여 회원 선택" 목록을 확인하기 위한 가짜 회원.
--   · 각 직군(교실·의국·심리실·연구실·PA·간호사·SW·보조원)별 1명
--   · 비밀번호 test1234, 가입 승인 완료(approved=true), 역할 user
-- 방식: auth.users 에 직접 삽입 → handle_new_user 트리거가 profiles 자동 생성
--       → 이후 approved=true 로 보정.
-- 주의: 테스트 전용입니다. 실제 운영 DB 에는 넣지 마세요.
--       정리(삭제)는 맨 아래 주석 참고. (auth.users 삭제 시 profiles 도 함께 삭제)
-- 실행: Supabase SQL Editor 에서 이 파일 전체를 한 번 실행.
-- ============================================================

create extension if not exists pgcrypto;  -- crypt() 사용

do $$
declare
  members text[] := array[
    '홍길동',   '교실',
    '김의국',   '의국',
    '이심리',   '심리실',
    '박연구',   '연구실',
    '최피에이', 'PA',
    '정간호',   '간호사',
    '강소셜',   'SW',
    '윤보조',   '보조원'
  ];
  uid  uuid;
  mail text;
  i    int;
begin
  for i in 1 .. (array_length(members, 1) / 2) loop
    mail := 'dummy' || i || '@psytalk.test';

    -- 이미 있으면 건너뜀 (재실행 안전)
    if exists (select 1 from auth.users where email = mail) then
      continue;
    end if;

    uid := gen_random_uuid();

    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password,
      email_confirmed_at, created_at, updated_at,
      raw_app_meta_data, raw_user_meta_data,
      confirmation_token, recovery_token, email_change_token_new, email_change
    ) values (
      '00000000-0000-0000-0000-000000000000', uid, 'authenticated', 'authenticated', mail,
      crypt('test1234', gen_salt('bf')),
      now(), now(), now(),
      '{"provider":"email","providers":["email"]}',
      jsonb_build_object('name', members[i*2 - 1], 'member_type', members[i*2]),
      '', '', '', ''
    );

    -- 트리거가 profiles 를 생성함. 이름·직군 보정 + 가입 승인 처리.
    update public.profiles
       set name        = members[i*2 - 1],
           approved    = true,
           role        = coalesce(role, 'user')
     where id = uid;
  end loop;
end $$;

-- 확인:
--   select id, name, member_type, role, approved from public.profiles order by name;

-- ------------------------------------------------------------
-- 정리(더미 회원 전부 삭제) — 필요할 때만 실행:
-- delete from auth.users where email like 'dummy%@psytalk.test';
-- ============================================================
