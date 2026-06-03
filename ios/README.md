# 모임톡 iOS (SwiftUI)

Android 앱(`/app`)과 **동일한 형식·논리**의 iOS 버전입니다.
**같은 Supabase 백엔드**(Auth/Postgres/Storage)와 **같은 도메인 규칙**(멤버 8직군·기본 12방·
권한·캘린더/자료실)을 공유합니다. 스펙은 루트 [`CLAUDE.md`](../CLAUDE.md)·[`docs/`](../docs)·
[`prototype/`](../prototype) 참고.

## 구조 (Android ↔ iOS 대응)

| Android (`app/.../`) | iOS (`ios/MoimTalk/`) |
|----------------------|------------------------|
| `data/SupabaseClient.kt` | `Supabase/SupabaseClient.swift` + `Supabase/Models.swift` |
| `data/MoimRepository.kt` | `Supabase/MoimRepository.swift` |
| `MainActivity.kt` (MoimViewModel) | `ViewModel/MoimViewModel.swift` + `MoimTalkApp.swift` |
| `ui/MoimDesign.kt` | `Design/MoimDesign.swift` |
| `ui/MoimScreens.kt` | `Views/LoginView.swift`, `RoomListView.swift`, `RoomView.swift`, `WardStatusView.swift`, `AdminPlaceholderView.swift` |
| `ui/CalendarFilesPanes.kt` | `Views/CalendarView.swift`, `FilesView.swift` |

## 빌드 방법 (Mac + Xcode 필요)

이 클라우드(Linux) 환경에선 빌드가 안 됩니다. Mac에서:

### A. XcodeGen 사용 (권장)
```bash
brew install xcodegen
cd ios
xcodegen generate      # MoimTalk.xcodeproj 생성
open MoimTalk.xcodeproj
```
의존성(supabase-swift)은 `project.yml` 에 선언돼 있어 Xcode가 자동으로 받습니다.

### B. 수동 설정
1. Xcode → New Project → iOS App (SwiftUI), 이름 `MoimTalk`, Bundle ID `com.example.moimtalk`
2. File → Add Package Dependencies → `https://github.com/supabase/supabase-swift` (2.0.0+)
3. `MoimTalk/` 아래 Swift 파일들을 프로젝트에 추가
4. 빌드·실행

## 로고
- 로그인 화면이 `Image("aumc_psy_logo")` 를 씁니다. Xcode 의 **Assets.xcassets** 에
  `aumc_psy_logo` 이름으로 로고 PNG(루트 `app/src/main/res/drawable/aumc_psy_logo.png` 와 동일)를 추가하세요.
  없으면 빈 영역으로만 표시되고 크래시는 없습니다.
- 앱 아이콘은 Assets 의 AppIcon 에 동일 로고를 넣으면 됩니다.

## 참고
- Supabase URL/anon 키는 `Supabase/SupabaseClient.swift` 에 Android와 동일하게 들어 있습니다.
- supabase-swift 버전에 따라 Storage `upload` 시그니처가 다를 수 있어, 빌드 에러 시
  `MoimRepository.swift` 의 `uploadToStorage` 만 설치된 버전에 맞춰 조정하세요.
