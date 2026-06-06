# CLAUDE.md — 아주 정신 (PsyTalk)

> 이 파일은 Claude Code가 매 세션 시작 시 자동으로 읽습니다.
> 정신건강의학과용 그룹 메신저 **아주 정신**의 핵심 규칙·구조·작업 방식을 요약합니다.
> 상세 스펙은 [`docs/아주정신_요구사항.md`](docs/아주정신_요구사항.md), 대조표는
> [`prototype/PARITY.md`](prototype/PARITY.md) 참고.

## 프로젝트 개요

- **무엇:** 대학병원 정신건강의학과 의국용 그룹 채팅·캘린더·자료실 앱
- **기술:** Android (Kotlin + Jetpack Compose) + Supabase (Auth/Postgres/Storage)
- **원본:** `prototype/index.html` (인터랙티브 HTML 목업) = UI/기능의 기준
- **언어:** UI·문서·커밋 설명 모두 한국어 우선

## 핵심 도메인 규칙 (변경 시 신중히)

### 회원 직군 (`member_type`, 13종)
교실 · 의국 · 심리실 · 연구실 · PA · 간호사 · SW · 보조원 · 생명사랑 · 비서 · 의국동문 · 심리실 동문 · 기타
> member_type 이 ENUM 이면 값 추가는 `supabase/add_member_types.sql` 실행.

### 역할·권한 (`role`)
- **superadmin** (전체관리자, 1명 = **jsnoh@ajou.ac.kr 고정**): 모든 방·회원·권한 관리, 과 전체공지·캘린더 작성, 방 참석자 지정.
  DB 트리거(`protect_superadmin.sql`)로 **퇴출(미승인)·강등·삭제 불가**, UI 목록에서도 제외.
- **admin** (관리자): superadmin이 지정, 공지·캘린더 작성 가능
- **user** (회원): 소속 방에서 정책에 따라 읽기/쓰기

### 공지 방 작성 정책 (`post_policy`)
- `restricted`: superadmin + admin + **방별 지정 작성자(writers)**만 작성 (예: 과 전체공지)
- `members`: 방 참석 회원 누구나 작성

### 기본 방 2개 (`sort_order` 1~2) — 항상 상단 고정
1 과 전체공지(notice·restricted) · 2 주간 학술활동(notice·members·**default_view=week**)
- 시드: `supabase/seed_rooms.sql`
- 그 아래 **모임 방**(`category=custom`): **사용자가 카톡처럼 직접 생성**(이름+참여회원 선택).
  생성자=`created_by`, 참석자=`room_members`. 모임방은 회원·생성자·관리자에게만 보임(RLS).
  권한·가시성: `supabase/room_create.sql`

### 캘린더 (방별)
- 보기: **금일 / 주간 / 월간** (`default_view=week` 방은 열면 캘린더 주간 목록으로 시작)
- 일정 필드: 제목·시간(timestamptz)·장소·링크·참석범위·설명·키워드(배열)·**첨부파일+첨부설명**
- 수정 권한: **작성자 본인 + superadmin/admin**

### 자료실 (방별)
- **캘린더 첨부 + 직접 업로드**를 한곳에 집계
- 정렬: **날짜순 / 키워드별**, 표시: 파일명 + 업로드 시 설명문
- 저장: **Supabase Storage `room-files` 버킷** (`supabase/storage_setup.sql`)

### 멀티 방 게시
- 한 방에서 글 작성 시 접근 권한 있는 다른 방에도 동시 게시 (중복 방지). 스키마 `message_cross_posts`. **앱 미구현(예정).**

## 저장소 구조 (모노레포 — Android + iOS 공용 백엔드)

```
app/  (Android, Kotlin + Compose)
  src/main/java/com/example/moimtalk/
    MainActivity.kt            # MoimViewModel(상태) + App() 네비게이션
    data/SupabaseClient.kt     # Supabase 클라이언트 + 직렬화 모델
    data/MoimRepository.kt     # 모든 Supabase 호출(메시지/일정/자료/스토리지)
    data/MoimRealtimeSync.kt   # Realtime 구독(방·채팅·일정·자료·병실)
    ui/MoimScreens.kt          # 로그인·방목록·방(채팅탭)·잔여 병실 현황·관리자(placeholder)
    ui/CalendarFilesPanes.kt   # 캘린더·자료실 패널 + 일정/업로드 다이얼로그
    ui/MoimDesign.kt           # 색상·라벨·권한 헬퍼
ios/  (iOS, SwiftUI + supabase-swift) — Android 구조를 1:1 미러링
  MoimTalk/Supabase/{SupabaseClient,Models,MoimRepository,MoimRealtimeSync}.swift
  MoimTalk/ViewModel/MoimViewModel.swift · Design/MoimDesign.swift
  MoimTalk/Views/{Login,RoomList,Room,Calendar,Files,WardStatus,...}.swift
  project.yml (XcodeGen) · README.md
web/  (브라우저 — Windows/Mac/iPad) — 단일 HTML + Supabase JS(UMD)
  index.html (전체 앱 기능 + 관리자 콘솔) · README.md
supabase/                      # SQL (아래 순서대로 실행) — 모든 클라이언트 공용 백엔드
docs/아주정신_요구사항.md          # 상세 요구사항(기준 문서)
prototype/index.html           # HTML 목업(기준), PARITY.md(대조표)
```

> **Android ↔ iOS 동일 형식·논리.** 백엔드(Supabase)·도메인 규칙·SQL은 한 벌을 공유하고
> 코드만 두 벌. 한쪽을 고치면 다른 쪽도 같은 구조로 맞춥니다. 대응표는 `ios/README.md`.

## Supabase 설정 순서
1. `fix_signup.sql` — 회원가입·profiles
2. `schema_extension.sql` — room_members, room_writers, calendar_events, room_files + RLS
3. `storage_setup.sql` — `room-files` 버킷·정책
4. `ward_status.sql` — 잔여 병실 현황 메모(단일 행)
5. `seed_rooms.sql` — 기본 2방(과 전체공지·주간 학술활동)
6. `install.sql` — GRANT·RLS
7. `room_create.sql` — 모임방 사용자 생성 권한·가시성
8. `admin_roles.sql` — 앱에서 역할 지정(전체관리자만) 권한
9. `room_manage.sql` — 모임방 삭제·회원 내보내기 RLS + **동일 이름 모임방 금지**(유니크 인덱스)
10. `realtime_setup.sql` — Realtime publication — 앱 **거의 실시간 동기화**에 필요
11. `signup_unapproved.sql` — **새 가입자는 불승인(approved=false)으로 시작** 강제(트리거) + superadmin 유지
12. `protect_superadmin.sql` — **전체관리자(jsnoh@ajou.ac.kr) 고정·보호**: superadmin+승인으로 보정 후
    누구도 퇴출(미승인)·강등·삭제 불가(BEFORE INSERT/UPDATE/DELETE 트리거)
13. `chat_attachments.sql` — **채팅 첨부(사진/파일)**: messages 에 `type`·`attachment_url`(공개 URL)·`attachment_name`
    컬럼 추가. 파일은 **공개 `room-files` 버킷**에 저장(누구나 URL 다운로드).
    카톡식 `+` 로 사진/파일 **선택 → 미리보기 → ➤(보내기) 눌러야 전송**.
14. `message_delete.sql` — **본인이 쓴 메시지(텍스트/사진/파일) 삭제** RLS(본인·관리자). 🗑 버튼/길게눌러 삭제.
15. `cleanup_old_files.sql` — **첨부/자료 4주 자동정리**(pg_cron): 채팅첨부·자료실 업로드 28일 경과 시
    스토리지+DB 삭제 + 스토리지 90% 초과 시 오래된 것부터. (대시보드에서 `pg_cron` 확장 먼저 활성화)
16. `read_tracking.sql` — **읽음 표시**: `room_reads` 테이블 + RPC(`moim_unread_counts`/`moim_message_unread_counts`/
    `moim_mark_read`/`moim_room_member_ids`). 안읽은 방 배지 + 메시지별 안읽은 사람 수에 **필수**.
17. `ward_calendar_perms.sql` — **ward 편집 / 일정 삭제 권한 제한**: ward 편집=관리자 또는 직군(교실·의국·간호사),
    일정 삭제=작성자/관리자/직군(교실·의국·비서·심리실). `moim_my_member_type()` 헬퍼. (일정 작성은 누구나)
18. `room_last_messages.sql` — **방 목록 마지막 메시지**: `moim_room_last_messages()`(방별 최근 1건).
    방이름 아래 미리보기 + 우측 시간(오늘=HH:mm/이전=M/d)에 사용.
19. `room_pins.sql` — **방 순서 개인 고정**: `room_pins`(user·room·position) + `moim_set_room_pins(uuid[])`.
    방목록 헤더 ⚙️로 최대 5개 고정·**드래그 정렬**, 나머지는 최근 메시지순.
    **과 전체공지 방은 항상 맨 위 고정·변경 불가**(핀 대상에서 제외, 5개 한도는 전체공지 제외). 헬퍼: `noticeTopRoom`(세 클라이언트).
20. `leave_account.sql` — **방 나가기 + 회원 탈퇴**: `room_members` DELETE 정책에 본인 추가(방 나가기) +
    `moim_delete_my_account()`. 방화면 **나가기**(본인이 만들지 않은 모임방) · ⚙️ 설정의 **회원 탈퇴**에 사용.
21. `admin_console.sql` — **관리자 콘솔 개편 + '탈퇴=비활성(글·자료 보존)'**:
    `profiles.withdrawn` 컬럼 + `moim_approve_user`(관리자/전체관리자 승인) +
    `moim_delete_my_account`/`moim_admin_withdraw`(비활성: 방·고정만 정리, **메시지·자료·일정·이름은 보존**,
    `auth.users.banned_until` 로 로그인 차단). **leave_account.sql 의 하드삭제를 비활성으로 덮어씀 → 반드시 실행.**
22. `room_appearance.sql` — **방표식(아바타) 색상·사진**: `rooms.color`(hex)·`rooms.icon_url` 컬럼.
    방 만들 때/이름변경 시 색상 팔레트 선택 + 사진 업로드(공개 `room-files`). 수정 권한은 기존 rooms UPDATE 정책.
23. `signup_extra_fields.sql` — **가입 추가정보(핸드폰·소개) + 핸드폰/이메일 로그인**: `profiles.intro` 컬럼 +
    가입 시 메타데이터(phone·intro)를 profiles 에 저장(BEFORE INSERT 트리거) + `moim_email_for_phone(phone)`(핸드폰→이메일,
    anon 허용). 가입칸=이름·핸드폰·이메일·비밀번호(+확인)·소개·직군, 로그인=**이메일 또는 핸드폰번호**+비밀번호.
24. `account_reactivate.sql` — **비활성(탈퇴) 계정 복구**: `moim_reactivate_user(uuid)`(전체관리자).
    withdrawn=false·approved=true 로 되돌리고 banned_until 해제 → 계정 UUID 그대로라 이전 메시지·자료 연결.
    관리자 콘솔 '회원 관리' 하단 **비활성 회원** 목록의 **복구** 버튼에서 사용.
25. `protect_superadmin_password.sql` — **전체관리자 비밀번호 변경 금지**: auth.users BEFORE UPDATE 트리거로
    superadmin(jsnoh@ajou.ac.kr)의 비밀번호(encrypted_password) 변경 시도를 차단(재설정·updateUser 모두).
    웹 로그인 화면의 '비밀번호 재설정'도 superadmin 이메일은 거부(클라이언트 1차 + 트리거 서버측 방어).
26. `profile_edit.sql` — **내정보 변경**: `profiles.avatar_url`·`color` 컬럼 + `moim_update_my_profile(intro,avatar_url,color)`
    (본인 안전 컬럼만 갱신). 설정 ⚙️ → **내 정보** 탭의 자기소개·아바타(사진/색) 저장에 사용. 이름·이메일은 읽기전용,
    비밀번호는 `auth.updateUser`(superadmin 차단).
27. `direct_messages.sql` — **1:1 다이렉트 채팅(카톡 DM식)**: `rooms.dm_key`(쌍 유일) + `category='direct'` +
    방 가시성 재정의(DM 은 당사자만) + `moim_open_direct(uuid)`(없으면 생성·양쪽 멤버십 보정 후 방 id 반환).
    설정 ⚙️ → **회원 검색**의 '메시지'에서 사용. 표시 이름·아바타는 dm_key 로 상대 프로필 계산.
28. `member_contact_email.sql` — **회원 검색·관리에 이메일 표시**: `profiles.email` 컬럼을 `auth.users.email` 과
    동기화(가입 시 채움 + 변경 시 트리거 + 기존 backfill). **회원 검색·회원 관리·가입 승인** 행에 이메일·전화번호·
    자기소개를 작은 글씨로 노출(세 플랫폼 공통). 전화번호·자기소개는 signup_extra_fields.sql 의 `phone`·`intro` 사용.

> (선택) `seed_dummy_members.sql` — 테스트용 더미 회원 8명(직군별). 운영 전 정리.

> `schema_extension.sql`이 `profiles` 조회를 "본인만→인증 사용자 전체"로 바꿉니다(작성자 이름 표시용).
> 캘린더/자료실 작성은 현재 `owner=본인`만 검사하며, `room_members` 연동 시 강화 예정.

## 작업 방식 (중요)

- **개발 브랜치:** `claude/moim-talk-chat-app-OhMZV` 에서 작업 → 커밋·푸시 후 `main`에 머지
- **빌드 한계:** 이 클라우드 환경엔 **Android SDK/Gradle가 없어 빌드·실행 검증 불가**.
  코드는 기존 패턴(Supabase-kt 3.3.0, Compose BOM 2024.12)을 따라 작성하고,
  실제 빌드·실행은 사용자가 Android Studio에서 확인.
- **리소스 파일명:** `res/drawable` 등은 **소문자·숫자·언더스코어만** (예: `aumc_psy_logo.png`)
- **현황 표:** 새 기능 추가/구현 시 `docs/아주정신_요구사항.md`의 구현 현황과 `prototype/PARITY.md`를 함께 갱신

## 관리자 콘솔 (관리 프로그램) — **세 플랫폼 공통, 3분할**
- 접근: **관리자(admin)·전체관리자(superadmin)**. 방목록의 **🛡 관리자 콘솔** 배너로 진입.
  - **admin** → **가입 승인 탭만** 보임.
  - **superadmin** → **가입 승인 · 회원 관리 · 방 관리** 3탭 전부.
  - 코드: iOS `AdminPlaceholderView`/`SignupApprovalView` · Android `AdminConsoleScreen`(MoimScreens.kt) · 웹 `#adminScreen`.
- **가입 승인**: **신규 가입자(미승인·미탈퇴)만** 표시. **승인** 버튼 → `moim_approve_user`(관리자도 가능).
  승인되면 목록에서 빠지고 **회원 관리** 명단으로 이동. 기본 **가나다순** + **직군별 보기** 토글.
- **회원 관리**(superadmin 전용): **승인된 회원**(미탈퇴) 목록. **관리자 지위 지정/해제**(admin↔user,
  `profiles` UPDATE = `admin_roles.sql` 전체관리자 전용 정책) + **계정 비활성화**(`moim_admin_withdraw`).
  하단에 **비활성 회원** 목록 + **복구**(`moim_reactivate_user`) — 복구 시 계정 UUID 그대로라 이전 대화 연결. iOS는 이름 편집도 가능.
- **방 관리**(superadmin 전용): 방을 누르면 **구성원 초대 / 제거(confirm) / 방 삭제(confirm)**.
  방 삭제는 **superadmin만**, **기본 방(전체공지·학술활동)은 삭제 불가**. (방 행 사이 구분선 없음)
- **계정 비활성화(탈퇴) = 소프트 삭제**: `moim_*` (admin_console.sql) 가 방·고정만 정리하고
  **메시지·자료·일정·작성자 이름은 보존**, `auth.users.banned_until` 로 로그인 차단. 본인 ⚙️ '회원 탈퇴'도 동일.
- **각 모임방 ⚙️ 설정**(콘솔과 별개): 방 생성자(비관리자 포함)가 **구성원 초대·제거 + 자신이 만든 방 삭제** 가능 (`room_manage.sql`).

## 아직 앱에 없는 것 (우선순위 참고)
멀티 방 게시 · `room_writers`(방 작성자 지정) 연동
(안 읽음 배지 ✅ · 메시지별 안읽은 수 ✅ · 캘린더 이동/복귀 ✅)

## 푸시 알림 (OneSignal)
- 앱 코드(iOS `Push.swift`·Android `Push.kt`·`MoimApp`)와 발송 함수(`supabase/functions/notify-message`)는 구현됨.
- **외부 설정 필요**(OneSignal 가입·Apple APNs 키·Firebase FCM·App ID 교체·Edge Function 배포·Database Webhook):
  **`docs/PUSH_SETUP.md`** 단계대로. 새 메시지 → 방 구성원(보낸이 제외)에게 푸시.
