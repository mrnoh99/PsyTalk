# 푸시 알림 설정 (OneSignal) — 새 메시지 알림

> **현재 상태:** 웹·iOS·Android **모두 코드 연동 완료**. App ID 는 코드에 박혀 있고
> (`web/index.html`·`Push.kt`·`Push.swift` = `4e52339e-…`), 아래 **외부 설정**(OneSignal 플랫폼 + Supabase 함수·웹훅)만 하면 동작합니다.
> - 웹: **[웹 푸시 설정]**
> - 네이티브: **[iOS]**, **[Android]**

---

## [웹 푸시 설정] — web/ (GitHub Pages: https://mrnoh99.github.io/PsyTalk/)

웹은 코드가 이미 준비돼 있고(`web/index.html` + `web/OneSignalSDKWorker.js`), App ID 입력 + OneSignal 웹 플랫폼 설정 + 아래 공통 5)번(함수·웹훅)만 하면 됩니다.

1. **OneSignal 앱**에 **Web** 플랫폼 추가(아래 1번에서 만든 앱에). "Typical Site"
   - **Site URL:** `https://mrnoh99.github.io/PsyTalk/`
   - **Default icon** 업로드(선택). (구독 프롬프트는 기본값으로 충분)
2. **App ID 입력:** `web/index.html` 상단 `const ONESIGNAL_APP_ID = "";` 에 OneSignal **App ID** 붙여넣기 → 커밋/배포(Pages 자동 배포).
3. **서비스워커:** `web/OneSignalSDKWorker.js` 가 이미 있어 `…/PsyTalk/OneSignalSDKWorker.js` 로 서빙됨(추가 작업 없음). 코드가 서브경로(`/PsyTalk/`) scope 를 자동 적용.
4. 아래 **5) Supabase 함수+웹훅** 을 설정(웹·앱 공통, 한 번만).
5. **동작 조건**
   - 데스크톱 Chrome/Edge/Firefox, 안드로이드 Chrome: 로그인 후 알림 허용하면 **앱을 닫아도** 수신.
   - **iOS/iPadOS: Safari 에서 '홈 화면에 추가'(PWA 설치) + iOS 16.4↑** 인 경우에만 수신(일반 사파리 탭 불가).
   - 같은 회원으로 폰 앱·웹을 함께 써도 OK(external_id 공유).

> 웹은 OneSignal 외 추가 빌드가 없습니다. App ID 만 비워두면 전체 비활성(기존 동작 영향 없음).

---

## (참고) iOS·Android 네이티브 앱 푸시 — 아직 미사용

Supabase Edge Function `notify-message` 는 저장소에 남아 있습니다. 앱 연동을 다시 넣은 뒤 **아래 외부 설정**을 하면 알림이 동작합니다.
구조: 앱이 OneSignal에 등록(external_id = Supabase 사용자 id) → 새 메시지 INSERT 시 Supabase
Database Webhook → Edge Function `notify-message` → OneSignal REST API로 그 방 구성원(보낸이 제외)에게 푸시.

---

## 1) OneSignal 앱 만들기
1. https://onesignal.com 가입 → **New App/Website** → 이름 "아주 정신".
2. 플랫폼 추가:
   - **Apple iOS (APNs)**: Apple Developer(유료 계정)에서 **APNs Auth Key(.p8)** 발급
     (Certificates, Identifiers & Profiles → Keys → + → Apple Push Notifications service).
     OneSignal에 업로드: **.p8 파일 + Key ID + Team ID + Bundle ID(`kr.ac.ajou.psytalk` Android / iOS 각각 등록)**.
   - **Google Android (FCM)**: Firebase 콘솔에서 프로젝트 생성 →
     프로젝트 설정 → 서비스 계정 → **Firebase Admin SDK 비공개 키(JSON)** 발급 →
     OneSignal에 업로드. (OneSignal Android는 내부적으로 FCM 사용)
3. OneSignal **App ID** 와 **REST API Key** 복사 (Settings → Keys & IDs).

## 2) App ID — 이미 코드에 반영됨
- App ID(`4e52339e-…`)는 `Push.kt`(Android)·`Push.swift`(iOS)·`web/index.html` 에 상수로 들어가 있습니다.
- 다른 OneSignal 앱을 쓰려면 그 세 곳의 상수만 바꾸면 됩니다.

## 3) [iOS] — 코드 구현됨 (Push.swift + project.yml)
앱 코드(초기화·권한요청·로그인연결)는 완료. 아래만 하면 됩니다.
1. **OneSignal에 Apple(APNs) 플랫폼 추가** — Apple Developer(유료)에서 **APNs Auth Key(.p8)** 발급
   (Keys → + → Apple Push Notifications service) → OneSignal에 **.p8 + Key ID + Team ID + Bundle ID** 업로드.
2. **빌드:** `cd ios && xcodegen generate` (OneSignal 패키지·`aps-environment` 엔타이틀먼트가 project.yml 에 포함됨).
3. Xcode → Target **MoimTalk → Signing & Capabilities**:
   - **Push Notifications** 가 엔타이틀먼트로 이미 잡혀 있음(없으면 **+ Capability → Push Notifications**).
   - (선택) **Background Modes → Remote notifications** — 데이터 푸시·확장용. 기본 알림엔 불필요.
   - Signing에 본인 Apple Developer 팀 선택.
4. **실기기**로 빌드(푸시는 시뮬레이터 제한). 로그인 후 알림 허용.

## 4) [Android] — 코드 구현됨 (Push.kt + build.gradle)
앱 코드(SDK·초기화·권한요청·로그인연결)는 완료. **google-services.json 불필요**(OneSignal 5.x 는 FCM 자격증명을 서버에 보관).
1. **OneSignal에 Google Android(FCM) 플랫폼 추가** — Firebase 콘솔에서 프로젝트 생성 →
   프로젝트 설정 → 서비스 계정 → **새 비공개 키(JSON)** 발급 → OneSignal **Settings → Platforms → Google Android (FCM)** 에 업로드.
2. Android Studio에서 그냥 빌드(의존성 `com.onesignal:OneSignal` 자동 받음).
3. Android 13+ 는 로그인 시 알림 권한 자동 요청(코드 포함).

## 5) Supabase — 발송 함수 + 웹훅
```bash
# (1) 함수 배포 (JWT 검증 끄고 — 웹훅이 호출)
supabase functions deploy notify-message --no-verify-jwt

# (2) 시크릿 등록
supabase secrets set ONESIGNAL_APP_ID=여기에-App-ID ONESIGNAL_REST_API_KEY=여기에-REST-Key
```
(3) **Database Webhook** 생성 — 대시보드 → Database → Webhooks → Create:
- Table: `public.messages`, Events: **Insert**
- Type: **HTTP Request**, Method: POST
- URL: `https://<프로젝트ref>.functions.supabase.co/notify-message`
- (헤더는 기본값으로 충분 — 함수는 `--no-verify-jwt` 로 배포)

`read_tracking.sql`(이미 적용)의 `moim_room_member_ids` 함수를 함수가 사용합니다.

---

## 동작 확인
1. 두 기기/계정 로그인(앱이 OneSignal에 external_id=사용자id로 등록).
2. A가 방에 메시지 → B 기기에 **방 이름 + "보낸사람: 내용"** 푸시.
3. 안 오면: OneSignal 대시보드 → Delivery 로그, Edge Function 로그(`supabase functions logs notify-message`) 확인.

## 참고
- 알림 대상은 **그 방 구성원(보낸이 제외)** — 기본방=승인 전원, 모임방=구성원.
- 본인이 보낸 메시지는 본인에게 안 옴.
- 웹·iOS·Android **모두 앱 코드 구현 완료**(초기화·권한요청·로그인 연결·로그아웃 해제). 남은 건 위 외부 설정뿐.
- 세 플랫폼이 같은 OneSignal 앱(같은 App ID)·같은 `external_id`(회원 id)를 쓰므로, 한 회원이 폰·웹 어디서 받든 동일하게 동작.
