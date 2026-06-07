# Android Play Store 배포 준비

`applicationId`: **`kr.ac.ajou.psytalk`**

## 1. 릴리스 서명 (필수)

```powershell
keytool -genkey -v -keystore release.keystore -alias psytalk -keyalg RSA -keysize 2048 -validity 10000
```

1. 프로젝트 루트에 `keystore.properties.example` → `keystore.properties` 복사
2. `storeFile`, 비밀번호, `keyAlias` 입력
3. Android Studio: **Build → Generate Signed Bundle / APK** 또는 `./gradlew bundleRelease`

`keystore.properties`·`*.keystore` 는 Git에 커밋하지 마세요.

## 2. OneSignal / FCM (푸시)

1. `local.properties` 에 OneSignal App ID 추가:
   ```
   onesignal.app.id=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
   ```
2. Firebase에서 `google-services.json` 발급 → `app/google-services.json` 에 저장
3. 상세: [`docs/PUSH_SETUP.md`](PUSH_SETUP.md)

App ID가 비어 있으면 앱은 정상 동작하고 푸시만 비활성화됩니다.

## 3. 개인정보처리방침

- URL: https://mrnoh99.github.io/PsyTalk/privacy.html (`web/privacy.html`)
- 앱 **설정 → 내 정보** 하단에서 링크
- Play Console **데이터 안전성**·스토어 등록 시 동일 URL 사용

## 4. 릴리스 빌드

```powershell
.\gradlew bundleRelease
```

산출물: `app/build/outputs/bundle/release/app-release.aab`

## 5. Play Console 체크리스트

- [ ] 내부 테스트 트랙에 AAB 업로드
- [ ] 데이터 안전성 (계정, 메시지, 사진, 기기 ID)
- [ ] 개인정보처리방침 URL
- [ ] 스크린샷·짧은/긴 설명 (한국어)
- [ ] `POST_NOTIFICATIONS` 권한 설명

## 6. 운영 Supabase

앱 배포 전 `CLAUDE.md` SQL 1~32 순서 실행·`seed_rooms.sql` 정책 확인.
