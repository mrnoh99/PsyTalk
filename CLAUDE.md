# CLAUDE.md — 모임톡 (PsyTalk)

> 이 파일은 Claude Code가 매 세션 시작 시 자동으로 읽습니다.
> 정신건강의학과용 그룹 메신저 **모임톡**의 핵심 규칙·구조·작업 방식을 요약합니다.
> 상세 스펙은 [`docs/모임톡_요구사항.md`](docs/모임톡_요구사항.md), 대조표는
> [`prototype/PARITY.md`](prototype/PARITY.md) 참고.

## 프로젝트 개요

- **무엇:** 대학병원 정신건강의학과 의국용 그룹 채팅·캘린더·자료실 앱
- **기술:** Android (Kotlin + Jetpack Compose) + Supabase (Auth/Postgres/Storage)
- **원본:** `prototype/index.html` (인터랙티브 HTML 목업) = UI/기능의 기준
- **언어:** UI·문서·커밋 설명 모두 한국어 우선

## 핵심 도메인 규칙 (변경 시 신중히)

### 멤버 8직군 (`member_type`)
교실 · 의국 · 심리실 · 연구실 · PA · 간호사 · SW · 보조원

### 역할·권한 (`role`)
- **superadmin** (전체관리자, 1명): 모든 방·멤버·권한 관리, 과 전체공지·캘린더 작성, 방 참석자 지정
- **admin** (관리자): superadmin이 지정, 공지·캘린더 작성 가능
- **user** (멤버): 소속 방에서 정책에 따라 읽기/쓰기

### 공지 방 작성 정책 (`post_policy`)
- `restricted`: superadmin + admin + **방별 지정 작성자(writers)**만 작성 (예: 과 전체공지)
- `members`: 방 참석 멤버 누구나 작성

### 기본 방 12개 (`sort_order` 1~12) — 항상 상단 고정
1 과 전체공지(notice·restricted) · 2 주간 학술활동(notice·members·**default_view=week**) ·
3 진료 공지(notice) · 4 교실·의국·심리실(group) · 5 교실 · 6 의국 · 7 심리실 ·
8 병동(work) · 9 외래(work) · 10 연구실 1(research) · 11 연구실 2 · 12 연구실 3
- 그 아래 **모임 방**(`category=custom`): 멤버가 추가 생성
- 시드: `supabase/seed_rooms.sql`

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

## 저장소 구조

```
app/src/main/java/com/example/moimtalk/
  MainActivity.kt              # MoimViewModel(상태) + App() 네비게이션
  data/SupabaseClient.kt       # Supabase 클라이언트 + 직렬화 모델
  data/MoimRepository.kt       # 모든 Supabase 호출(메시지/일정/자료/스토리지)
  ui/MoimScreens.kt            # 로그인·방목록·방(채팅탭)·관리자(placeholder)
  ui/CalendarFilesPanes.kt     # 캘린더·자료실 패널 + 일정/업로드 다이얼로그
  ui/MoimDesign.kt             # 색상·라벨·권한 헬퍼
supabase/                      # SQL (아래 순서대로 실행)
docs/모임톡_요구사항.md          # 상세 요구사항(기준 문서)
prototype/index.html           # HTML 목업(기준), PARITY.md(대조표)
```

## Supabase 설정 순서
1. `fix_signup.sql` — 회원가입·profiles
2. `schema_extension.sql` — room_members, room_writers, calendar_events, room_files + RLS
3. `storage_setup.sql` — `room-files` 버킷·정책
4. `seed_rooms.sql` — 기본 12방
5. `install.sql` — GRANT·RLS

> `schema_extension.sql`이 `profiles` 조회를 "본인만→인증 사용자 전체"로 바꿉니다(작성자 이름 표시용).
> 캘린더/자료실 작성은 현재 `owner=본인`만 검사하며, `room_members` 연동 시 강화 예정.

## 작업 방식 (중요)

- **개발 브랜치:** `claude/moim-talk-chat-app-OhMZV` 에서 작업 → 커밋·푸시 후 `main`에 머지
- **빌드 한계:** 이 클라우드 환경엔 **Android SDK/Gradle가 없어 빌드·실행 검증 불가**.
  코드는 기존 패턴(Supabase-kt 3.3.0, Compose BOM 2024.12)을 따라 작성하고,
  실제 빌드·실행은 사용자가 Android Studio에서 확인.
- **리소스 파일명:** `res/drawable` 등은 **소문자·숫자·언더스코어만** (예: `aumc_psy_logo.png`)
- **현황 표:** 새 기능 추가/구현 시 `docs/모임톡_요구사항.md`의 구현 현황과 `prototype/PARITY.md`를 함께 갱신

## 아직 앱에 없는 것 (우선순위 참고)
멀티 방 게시 · 관리자 콘솔(멤버/방/작성자 관리) · 모임방 생성 · `room_members`/`room_writers` 연동 ·
방 목록의 마지막 메시지·안 읽음 배지
