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

### 멤버 직군 (`member_type`, 12종)
교실 · 의국 · 심리실 · 연구실 · PA · 간호사 · SW · 보조원 · 비서 · 의국동문 · 심리실 동문 · 기타
> member_type 이 ENUM 이면 값 추가는 `supabase/add_member_types.sql` 실행.

### 역할·권한 (`role`)
- **superadmin** (전체관리자, 1명 = **jsnoh@ajou.ac.kr 고정**): 모든 방·멤버·권한 관리, 과 전체공지·캘린더 작성, 방 참석자 지정.
  DB 트리거(`protect_superadmin.sql`)로 **퇴출(미승인)·강등·삭제 불가**, UI 목록에서도 제외.
- **admin** (관리자): superadmin이 지정, 공지·캘린더 작성 가능
- **user** (멤버): 소속 방에서 정책에 따라 읽기/쓰기

### 공지 방 작성 정책 (`post_policy`)
- `restricted`: superadmin + admin + **방별 지정 작성자(writers)**만 작성 (예: 과 전체공지)
- `members`: 방 참석 멤버 누구나 작성

### 기본 방 2개 (`sort_order` 1~2) — 항상 상단 고정
1 과 전체공지(notice·restricted) · 2 주간 학술활동(notice·members·**default_view=week**)
- 시드: `supabase/seed_rooms.sql`
- 그 아래 **모임 방**(`category=custom`): **사용자가 카톡처럼 직접 생성**(이름+참여멤버 선택).
  생성자=`created_by`, 참석자=`room_members`. 모임방은 멤버·생성자·관리자에게만 보임(RLS).
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
9. `room_manage.sql` — 모임방 삭제·멤버 내보내기 RLS + **동일 이름 모임방 금지**(유니크 인덱스)
10. `realtime_setup.sql` — Realtime publication — 앱 **거의 실시간 동기화**에 필요
11. `signup_unapproved.sql` — **새 가입자는 불승인(approved=false)으로 시작** 강제(트리거) + superadmin 유지
12. `protect_superadmin.sql` — **전체관리자(jsnoh@ajou.ac.kr) 고정·보호**: superadmin+승인으로 보정 후
    누구도 퇴출(미승인)·강등·삭제 불가(BEFORE INSERT/UPDATE/DELETE 트리거)
13. `chat_attachments.sql` — **채팅 첨부(사진/파일)**: messages 에 `type`·`attachment_url`(공개 URL)·`attachment_name`
    컬럼 추가. 파일은 **공개 `room-files` 버킷**에 저장(누구나 URL 다운로드).
    카톡식 `+` 로 사진/파일 **선택 → 미리보기 → ➤(보내기) 눌러야 전송**.

> (선택) `seed_dummy_members.sql` — 테스트용 더미 멤버 8명(직군별). 운영 전 정리.

> `schema_extension.sql`이 `profiles` 조회를 "본인만→인증 사용자 전체"로 바꿉니다(작성자 이름 표시용).
> 캘린더/자료실 작성은 현재 `owner=본인`만 검사하며, `room_members` 연동 시 강화 예정.

## 작업 방식 (중요)

- **개발 브랜치:** `claude/moim-talk-chat-app-OhMZV` 에서 작업 → 커밋·푸시 후 `main`에 머지
- **빌드 한계:** 이 클라우드 환경엔 **Android SDK/Gradle가 없어 빌드·실행 검증 불가**.
  코드는 기존 패턴(Supabase-kt 3.3.0, Compose BOM 2024.12)을 따라 작성하고,
  실제 빌드·실행은 사용자가 Android Studio에서 확인.
- **리소스 파일명:** `res/drawable` 등은 **소문자·숫자·언더스코어만** (예: `aumc_psy_logo.png`)
- **현황 표:** 새 기능 추가/구현 시 `docs/아주정신_요구사항.md`의 구현 현황과 `prototype/PARITY.md`를 함께 갱신

## 관리자 콘솔 (관리 프로그램)
- **iOS(iPad/Mac) 앱에만** 포함. 접근 = **전체관리자(superadmin)만**. `ios/.../AdminPlaceholderView.swift`
  (iPad 앱이 Apple Silicon Mac에서 실행됨. `project.yml` device family `1,2`)
- **탭: 방 관리 + 가입 승인**
- **가입 승인 화면**(iOS 콘솔 탭 + Android `ApprovalScreen`): 미승인 → **승인**, 승인됨 → **퇴출**(=승인 취소).
  **전체관리자(superadmin)는 목록에서 제외**. 기본 **가나다순**(상태가 바뀌어도 줄 위치 유지) + **직군별 보기** 토글.
- 멤버: **역할 지정**(관리자/멤버 **둘만** — 전체관리자는 콘솔에서 지정 불가, 목록에도 미표시) + **이름 편집** 앱에서 직접(SQL 없이).
  변경 권한은 `admin_roles.sql`(전체관리자만, SECURITY DEFINER `moim_is_superadmin()` + profiles UPDATE 정책).
- 방 관리: 방을 누르면 **구성원 초대 / 구성원 제거(confirm) / 방 삭제(confirm)**.
  방 삭제는 **superadmin만**, **기본 방(전체공지·학술활동)은 삭제 불가**.
- **Android·웹·iOS 폰**: 관리자 콘솔 없음. 단, **각 모임방 ⚙️ 설정**에서 방 생성자(비관리자 포함)가
  **구성원 초대·제거 + 자신이 만든 방 삭제** 가능. 방 삭제 권한 = 생성자 또는 superadmin (`room_manage.sql`).

## 아직 앱에 없는 것 (우선순위 참고)
멀티 방 게시 · `room_writers`(방 작성자 지정) 연동 ·
방 목록의 마지막 메시지·안 읽음 배지
(모임방 생성 ✅ 카톡식 누구나 · 관리자 콘솔 ✅ iPad/Mac superadmin: 조회+역할지정)
