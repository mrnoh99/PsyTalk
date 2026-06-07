# 푸시 알림 설정 (OneSignal) — 새 메시지 알림

> **현재 상태:** iOS·Android 앱에서 OneSignal 연동은 **사용하지 않습니다**. 아래는 나중에 푸시를 도입할 때 참고용입니다.

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

## 2) 앱에 App ID 넣기
- **Android**: 프로젝트 루트 `local.properties` 에 `onesignal.app.id=...` 추가 (`local.properties.example` 참고)
- **iOS**: `ios/MoimTalk/Push.swift` 의 `oneSignalAppId = "ONESIGNAL_APP_ID"` 교체
- Android FCM: Firebase `google-services.json` → `app/google-services.json`

## 3) iOS 빌드 설정 (Xcode)
1. `cd ios && xcodegen generate` (OneSignal 패키지가 project.yml에 추가돼 있음)
2. Xcode에서 Target **MoimTalk → Signing & Capabilities**:
   - **+ Capability → Push Notifications** 추가
   - **+ Capability → Background Modes → Remote notifications** 체크
   - Signing에 본인 Apple Developer 팀 선택
3. 실기기로 빌드(푸시는 시뮬레이터 일부 제한). 첫 실행 시 알림 권한 허용.
   - (선택) 확인 전달률을 위해 OneSignal **Notification Service Extension** 추가 가능 — 기본 알림은 위만으로 동작.

## 4) Android 빌드 설정
- `app/google-services.json` (Firebase) + `local.properties` 의 `onesignal.app.id`
- 상세: [`docs/PUBLISH_ANDROID.md`](PUBLISH_ANDROID.md)
- Android 13+ 는 첫 실행 시 알림 권한 요청(코드에 포함됨).

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
- 앱 코드(권한 요청·로그인 연결·로그아웃 해제)는 이미 구현됨. App ID만 넣으면 됨.
