-- =============================================================================
-- check_migrations.sql — 설치(마이그레이션) 점검용 1회 조회
--   각 SQL 이 실제로 적용됐는지(테이블·컬럼·함수·트리거·시드 존재) 한 번에 확인.
--   Supabase SQL Editor 에 붙여넣고 Run → '상태' 가 ❌ 인 줄의 SQL 을 실행하면 됨.
--   ※ 읽기 전용(데이터 변경 없음). 안전하게 여러 번 실행 가능.
-- =============================================================================
WITH c(step, item, ok) AS (
  VALUES
  (1, 'fix_signup.sql — profiles 테이블 + 가입 트리거',
      (to_regclass('public.profiles') IS NOT NULL
       AND EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='on_auth_user_created')
       AND EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='handle_new_user'))),
  (2, 'schema_extension.sql — room_members/calendar_events/room_files/room_writers',
      (to_regclass('public.room_members') IS NOT NULL AND to_regclass('public.calendar_events') IS NOT NULL
       AND to_regclass('public.room_files') IS NOT NULL AND to_regclass('public.room_writers') IS NOT NULL)),
  (3, 'storage_setup.sql — room-files 버킷',
      EXISTS(SELECT 1 FROM storage.buckets WHERE id='room-files')),
  (4, 'ward_status.sql — ward_status 테이블',
      (to_regclass('public.ward_status') IS NOT NULL)),
  (5, 'seed_rooms.sql — 기본 2방(전체공지·학술활동) 시드',
      (EXISTS(SELECT 1 FROM public.rooms WHERE id='11111111-1111-1111-1111-111111110001')
       AND EXISTS(SELECT 1 FROM public.rooms WHERE id='11111111-1111-1111-1111-111111110012'))),
  (6, 'install.sql — messages RLS 정책',
      EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='messages')),
  (7, 'room_create.sql — rooms.created_by',
      EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='rooms' AND column_name='created_by')),
  (8, 'admin_roles.sql — moim_is_superadmin()',
      EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='moim_is_superadmin')),
  (9, 'room_manage.sql — moim_my_room_ids()/moim_is_room_owner()',
      (EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='moim_my_room_ids')
       AND EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='moim_is_room_owner'))),
  (10, 'realtime_setup.sql — supabase_realtime 에 messages 포함',
      EXISTS(SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='messages')),
  (11, 'signup_unapproved.sql — profiles.approved + 불승인 트리거',
      (EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='approved')
       AND EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='trg_profiles_force_unapproved'))),
  (12, 'protect_superadmin.sql — 보호 트리거',
      EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='trg_profiles_protect_superadmin')),
  (13, 'chat_attachments.sql — messages.type/attachment_url',
      (EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='messages' AND column_name='type')
       AND EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='messages' AND column_name='attachment_url'))),
  (14, 'message_delete.sql — messages DELETE 정책',
      EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='messages' AND cmd='DELETE')),
  (15, 'cleanup_old_files.sql — moim_cleanup_old_files()',
      EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='moim_cleanup_old_files')),
  (16, 'read_tracking.sql — room_reads + 안읽음 RPC',
      (to_regclass('public.room_reads') IS NOT NULL
       AND EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='moim_message_unread_counts'))),
  (17, 'ward_calendar_perms.sql — moim_my_member_type()',
      EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='moim_my_member_type')),
  (18, 'room_last_messages.sql — moim_room_last_messages()',
      EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='moim_room_last_messages')),
  (19, 'room_pins.sql — room_pins + moim_set_room_pins()',
      (to_regclass('public.room_pins') IS NOT NULL
       AND EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='moim_set_room_pins'))),
  (20, 'leave_account.sql — moim_delete_my_account()',
      EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='moim_delete_my_account')),
  (21, 'admin_console.sql — profiles.withdrawn + moim_admin_withdraw()',
      (EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='withdrawn')
       AND EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='moim_admin_withdraw'))),
  (22, 'room_appearance.sql — rooms.color/icon_url',
      (EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='rooms' AND column_name='color')
       AND EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='rooms' AND column_name='icon_url'))),
  (23, 'signup_extra_fields.sql — profiles.phone/intro + moim_email_for_phone()',
      (EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='phone')
       AND EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='intro')
       AND EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='moim_email_for_phone'))),
  (24, 'account_reactivate.sql — moim_reactivate_user()',
      EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='moim_reactivate_user')),
  (25, 'protect_superadmin_password.sql — 비밀번호 변경 차단 트리거',
      EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='trg_block_superadmin_password')),
  (26, 'profile_edit.sql — profiles.avatar_url + moim_update_my_profile()',
      (EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='avatar_url')
       AND EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='moim_update_my_profile'))),
  (27, 'direct_messages.sql — rooms.dm_key + moim_open_direct()',
      (EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='rooms' AND column_name='dm_key')
       AND EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='moim_open_direct'))),
  (28, 'member_contact_email.sql — profiles.email + 이메일 동기화 트리거',
      (EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='email')
       AND EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='trg_users_sync_email'))),
  (29, 'bugreport_room_seed.sql — BugReport 고정 방 시드',
      EXISTS(SELECT 1 FROM public.rooms WHERE id='11111111-1111-1111-1111-111111110013')),
  (30, 'message_reactions.sql — message_reactions + messages.reply_to + RPC',
      (to_regclass('public.message_reactions') IS NOT NULL
       AND EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='messages' AND column_name='reply_to')
       AND EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='moim_room_reactions'))),
  (31, 'signup_device.sql — profiles.device_type/device_email',
      (EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='device_type')
       AND EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='device_email'))),
  (32, 'profile_phone_edit.sql — profiles.phone_updated_at + 전화변경 트리거',
      (EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='phone_updated_at')
       AND EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='trg_profiles_track_phone')))
)
SELECT step AS "순서",
       CASE WHEN ok THEN '✅ OK' ELSE '❌ 누락(실행 필요)' END AS "상태",
       item AS "마이그레이션 · 핵심 객체"
FROM c
ORDER BY step;

-- 요약: 누락 개수
-- SELECT count(*) FILTER (WHERE NOT ok) AS "누락 수" FROM ( ... 위 WITH 동일 ... );
-- =============================================================================
