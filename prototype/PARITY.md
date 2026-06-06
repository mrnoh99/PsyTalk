# 프로토타입 ↔ 앱 대조표 (Parity)

> **목적:** `prototype/index.html`(HTML 목업)과 Android 앱(`app/.../`)이 서로 어디까지
> 일치하는지 한눈에 보는 기준표. 새 기능을 넣을 때 이 표를 갱신하세요.
>
> 기준일: 2026-06 · 앱 브랜치 `main`

| 기능 | 프로토타입 (`index.html`) | 앱 (`app/...`) | 일치 | 비고 |
|------|---------------------------|----------------|:----:|------|
| 방 목록 — 기본 12방 + 모임방, 카테고리 색·라벨·우선순위 번호 | ✅ | ✅ `RoomListScreen`/`RoomRow` | ✅ | |
| 방 목록 행 — 마지막 메시지·시간·**안 읽음 배지**·회원 수 | ✅ | ❌ (정책 설명만 표시) | ➖ | 앱은 last/unread/회원수 미표시 |
| 시점 전환 (10명 칩으로 전환) | ✅ 데모용 | ❌ 로그인 사용자 1명 | ✅ | **의도된 차이** (목업=데모, 앱=실제 로그인) |
| 채팅 | ✅ | ✅ `ChatPane` | ✅ | Supabase `messages` + **Realtime** (수 초 이내 동기화) |
| 방 목록·이름 변경·모임방 추가/삭제 (다른 기기) | ➖ | ✅ Realtime `rooms`/`room_members` | ✅ | Android·iOS·Web 공통 (`realtime_setup.sql`) |
| **멀티 방 게시 (📤 방선택)** | ✅ | ❌ | ❌ | 앱 미구현 (`message_cross_posts` 스키마만 존재) |
| 공지방 읽기 전용 (`restricted`) | ✅ | ✅ `canPostInRoom` | ✅ | 앱은 관리자만 작성 (지정 작성자 미연동) |
| 캘린더 — 금일/주간/월간 | ✅ | ✅ `CalendarPane` | ✅ | |
| 캘린더 — 일정 추가/수정, 시간·장소·링크·참석범위·설명·키워드·첨부 | ✅ | ✅ `calendar_events` | ✅ | |
| 캘린더 — 수정 권한(작성자+관리자) | ✅ | ✅ RLS + `canEditEvent` | ✅ | |
| `default_view='week'` 방 → 열면 캘린더 주간 목록 | ✅ 자동 | ✅ (탭 초기값 = cal) | ✅ | 2026-06 수정 반영 |
| 자료실 — 날짜순/키워드별, 캘린더 첨부 집계, 파일명+설명 | ✅ | ✅ `FilesPane` | ✅ | |
| 파일 스토리지 | 🔲 (alert 목업) | ✅ Supabase Storage `room-files` | ✅ | 앱이 실제 업로드 |
| 관리자 콘솔 — 3분할(가입승인·회원관리·방관리) | ➖ | ✅ 세 플랫폼 공통 | ✅ | admin=가입승인만, superadmin=전부. `admin_console.sql` |
| 가입 승인 (신규 가입자) | ➖ | ✅ 승인 → 회원관리로 이동 | ✅ | `moim_approve_user`(관리자도 가능) |
| 회원 관리 — 관리자 지위/계정 비활성화 | ➖ | ✅ superadmin 전용 | ✅ | 역할토글 + `moim_admin_withdraw` |
| 회원 검색·관리·가입승인 행에 이메일·전화번호·소개 표시 | ➖ | ✅ 작은 글씨 노출 | ✅ | 세 플랫폼 공통, `member_contact_email.sql`(profiles.email 동기화) |
| 방 열었을 때 상단 바에 개설자·참여자 이름 나열 | ➖ | ✅ 작은 글씨, 넘치면 … | ✅ | 세 플랫폼 공통, 개설자 먼저+이름순, DM 제외 |
| 1:1 대화 스와이프 삭제 (내 목록에서만) | ➖ | ✅ 왼쪽 스와이프 → 확인 | ✅ | 본인 room_members 만 제거(상대·이력 보존, 재오픈 복구). iOS=DragGesture, Android=SwipeToDismissBox, 웹=touch swipe |
| 방 안 우상단 '방삭제' 버튼 | ➖ | ✅ 헤더 우상단 → 확인 | ✅ | 모임방 생성자·전체관리자만(`canDeleteRoom`). 확인 후 방·메시지·일정·자료 삭제 |
| 다크/라이트 화면 테마 토글 (기본 다크) | ➖ | ✅ 설정 '내 정보'에서 전환 | ✅ | 저장(웹 localStorage·Android SharedPreferences·iOS UserDefaults). 내 버블=Primary(파랑). Android `MoimTheme`, iOS `ThemeManager`, 웹 `html.light` 클래스 |
| 계정 비활성화/탈퇴 = 소프트(글·자료 보존) | ➖ | ✅ | ✅ | 방·고정만 정리, 메시지·자료·이름 보존, `banned_until` 로그인 차단 |
| 방 만들기 (모임방 생성) | ✅ (관리자) | ✅ 누구나 (카톡식) | ✅ | 앱은 이름+회원선택, room_members 등록, RLS 비공개 |
| 방 이름 수정 (생성 후) | ➖ | ✅ 방 헤더 ✏️ (생성자/관리자) | ✅ | iOS·Android·Web 공통, RLS `rooms_update_owner_admin` |
| 관리자 콘솔 — 작성자 지정 (writers) | ✅ | ❌ | ❌ | `room_writers` 스키마만 존재 |
| 방 참석 회원 지정 (`room_members`) | ✅ (목 데이터) | ❌ | ❌ | 스키마만 존재, 앱 미연동 |
| 샘플 데이터 (10명·일정 5개·파일) | ✅ JS 목 데이터 | ➖ DB 실데이터 | ✅ | 목업 샘플은 데모 전용. 앱은 시드(방 12개)만, 일정/파일은 사용자 입력 |
| 방 순서 고정 — 드래그 정렬 | ➖ | ✅ ⚙️ 설정(드래그 ☰) | ✅ | 최대 5개 핀, `room_pins`/`moim_set_room_pins`. 웹=HTML5 DnD, Android=longpress drag, iOS=List `.onMove` |
| 과 전체공지 방 = 항상 맨 위 고정·변경 불가 | ✅ | ✅ 핀 대상 제외·맨 위 고정 | ✅ | 5개 한도는 전체공지 제외. 헬퍼 `noticeTopRoom` 세 플랫폼 공통 |
| 방 나가기 (본인이 만들지 않은 모임방) | ➖ | ✅ 방 헤더 나가기 | ✅ | 확인 후 `room_members` 본인 삭제, `leave_account.sql` RLS |
| 회원 탈퇴 (계정·내 데이터 삭제) | ➖ | ✅ ⚙️ 설정 회원 탈퇴 | ✅ | `moim_delete_my_account()`(전체관리자 불가). 웹=핀 모달 상단, 앱=설정에 로그아웃 동거 |
| 채팅방 열기 슬라이드(우→좌) | ➖ | ✅ slideInRight | ✅ | 웹=CSS keyframe, Android=`slideInHorizontally`, iOS=`.move(edge:.trailing)` |

**범례:** ✅ 일치 · ❌ 불일치(앱 미구현) · ➖ 의도된 차이/부분

---

## 핵심 차이 요약

1. **데이터 원천** — 프로토타입은 JS 목 데이터(10명·샘플 일정), 앱은 Supabase 실데이터.
   목업의 샘플 일정·파일은 **데모용**이라 앱 DB에는 없습니다(방 12개만 시드).
2. **아직 앱에 없는 것** — 멀티 방 게시, 관리자 콘솔(회원/방/작성자 관리), 방 만들기,
   `room_members`/`room_writers` 연동, 방 목록 행의 마지막 메시지·안 읽음 배지.
3. **앱이 프로토타입보다 나은 것** — 파일 스토리지가 실제로 동작(Supabase Storage),
   캘린더 일정이 실제 timestamptz로 저장되어 금일/주간/월간 분류가 진짜로 됩니다.

## 둘을 비교하는 방법

- 프로토타입을 브라우저에서 열기: `prototype/index.html` 더블클릭
- 앱 화면 코드: `app/src/main/java/com/example/moimtalk/ui/` (`MoimScreens.kt`, `CalendarFilesPanes.kt`)
- 두 화면을 나란히 두고 이 표로 항목별 확인
