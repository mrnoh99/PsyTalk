# iOS TestFlight 배포 안내 (아주 정신)

iOS 앱을 **TestFlight**로 베타 배포해 의국 구성원이 설치·테스트하게 하는 절차입니다.
앱 코드는 준비돼 있고(Bundle ID `com.mrnoh99.psytalk`, 푸시 연동 포함), 아래는 **빌드 → 업로드 → 테스터 초대** 흐름입니다.

> 관련 문서: 푸시 설정 `docs/PUSH_SETUP.md`, 출시 노트 `docs/RELEASE_NOTES.md`

---

## 0. 사전 준비 (1회)
- **Apple Developer Program 유료 멤버십**($99/년) — 없으면 TestFlight 불가.
- **Mac + Xcode** (최신).
- **XcodeGen**: `brew install xcodegen`
- Bundle ID `com.mrnoh99.psytalk` 가 Apple Developer에 등록돼 있음(이미 됨 — Xcode 자동 생성된 것 사용).

---

## 1. App Store Connect 에 앱 등록 (1회)
1. https://appstoreconnect.apple.com → **나의 앱 → ＋ → 새로운 앱**
2. 입력:
   - **플랫폼:** iOS
   - **이름:** 아주 정신 (스토어 표시 이름)
   - **기본 언어:** 한국어
   - **번들 ID:** `com.mrnoh99.psytalk` 선택
   - **SKU:** 아무 고유 문자열(예: `psytalk-ios`)
3. 생성. (스토어 심사 제출 전이라도 TestFlight는 됩니다)

---

## 2. Xcode에서 빌드·아카이브
```bash
cd ios
xcodegen generate
open MoimTalk.xcodeproj
```
Xcode에서:
1. 상단 대상 드롭다운을 **"Any iOS Device (arm64)"** 로 설정
   - ⚠️ **"My Mac"·"Mac (Designed for iPad)" 아님** — Mac으로 아카이브하면
     `LSApplicationCategoryType`·`app-sandbox` 검증 오류가 납니다.
2. Target **MoimTalk → Signing & Capabilities** → **Team** = 본인 Apple Developer 팀(자동 서명)
3. **Product → Archive**
4. 끝나면 **Organizer** 창이 뜨고 아카이브 종류가 **"iOS App"** 인지 확인.

---

## 3. App Store Connect 로 업로드
1. Organizer에서 해당 아카이브 선택 → **Distribute App**
2. **App Store Connect → Upload** 선택 → 기본값으로 진행 → **Upload**
3. 업로드 후 App Store Connect에서 **처리(Processing)** 가 끝날 때까지 5~30분 대기.

---

## 4. TestFlight 설정
App Store Connect → 해당 앱 → **TestFlight** 탭.

### (가벼움) 내부 테스트 — 최대 100명, 심사 없음
1. **내부 테스트 그룹** 생성(또는 기본 그룹)
2. **테스터 추가** — App Store Connect **사용자(팀 멤버)** 의 이메일.
   - 팀에 사람을 추가하려면: App Store Connect → **사용자 및 액세스** 에서 초대.
3. 처리 끝난 빌드를 그룹에 추가하면 테스터에게 초대가 갑니다.

### (대규모) 외부 테스트 — 최대 10,000명, **베타 심사 필요**
1. **외부 테스트 그룹** 생성 → 테스터 이메일 추가(또는 **공개 링크** 발급)
2. 빌드에 **테스트 정보**(연락 이메일·테스트 안내) 입력 → **베타 심사 제출**
3. 보통 하루 내 승인되면 초대/링크로 설치 가능.
   - 의국 전체 배포엔 **공개 링크**가 편합니다.

---

## 5. 테스터가 설치하는 법
1. iPhone/iPad에서 App Store에서 **TestFlight** 앱 설치
2. 받은 **초대 메일/공개 링크** 열기 → TestFlight에서 **아주 정신** 설치
3. 앱 실행 → 가입/로그인 → **알림 허용**(푸시 받으려면)

> 안내문에 넣을 한 줄: “TestFlight 앱 설치 → 받은 링크로 ‘아주 정신’ 설치 → 로그인 후 알림 허용”

---

## 6. 새 버전 올릴 때
- `project.yml` 의 **`CURRENT_PROJECT_VERSION`**(빌드 번호)을 **+1** (예: 1 → 2). 같은 번호면 업로드 거부됩니다.
  - (필요 시 `MARKETING_VERSION` 도 올림: 1.0 → 1.1)
- `xcodegen generate` → Archive → Upload 반복.
- 새 빌드를 TestFlight 그룹에 추가하면 테스터에게 자동 업데이트 알림.

---

## 자주 나는 오류
| 증상 | 원인·해결 |
|---|---|
| `LSApplicationCategoryType` / `app-sandbox` 검증 실패, 경로에 `Contents/MacOS` | **Mac으로 아카이브함** → 대상을 **Any iOS Device** 로 바꿔 다시 Archive |
| `Bundle ID ... not available` | 이미 등록된 것 → 새로 만들지 말고 기존 `com.mrnoh99.psytalk` 사용 |
| 빌드 번호 중복 업로드 거부 | `CURRENT_PROJECT_VERSION` +1 후 재빌드 |
| 푸시가 안 옴 | OneSignal에 **APNs(.p8)** 업로드 + `notify-message` 배포·웹훅 (`docs/PUSH_SETUP.md`) |
| 심사용 로그인 안내 | 승인된 테스트 계정 제공 (App access). 자세히는 `docs/PUSH_SETUP.md`/스토어 안내 |

---

## 이 앱 특유의 주의
- **가입 후 전체관리자 승인**이 있어야 사용 가능 → 테스터에게 “가입하면 관리자 승인 후 이용 가능” 안내. (외부 심사 시엔 승인된 테스트 계정 제공)
- **푸시 알림**은 OneSignal APNs 설정이 끝나야 옵니다. 안 끝났으면 알림만 안 오고 나머지 기능은 정상.
- 표시 이름은 **아주 정신**(MoimTalk은 내부 명칭).
