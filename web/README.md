# 아주 정신 Web (Windows / Mac / iPad 브라우저)

Android(`app/`)·iOS(`ios/`)와 **같은 Supabase 백엔드**에 연결되는 웹 버전입니다.
브라우저만 있으면 **Windows·Mac·iPad·어디서나** 동작합니다. 관리자 콘솔(멤버/방)도 포함.

## 실행 방법

### 가장 간단: 파일 더블클릭
`web/index.html` 을 브라우저로 열면 됩니다. (Supabase JS를 UMD CDN으로 불러와 파일 직접 열기 가능)

### 권장: 로컬 서버 (일부 브라우저의 file:// 제약 회피)
```bash
cd web
python3 -m http.server 8080
# 브라우저에서 http://localhost:8080
```

### 배포(여러 사람이 URL로 접속)
`web/index.html` 한 파일을 아무 정적 호스팅에 올리면 됩니다:
- GitHub Pages, Netlify, Vercel, Cloudflare Pages 등에 `web/` 폴더를 올리면 끝.

## 기능 (네이티브 앱과 동일)
- 로그인(이메일/비밀번호) · 세션 유지
- 방 목록(병실 잔여 현황 배너 + 기본 2방 + 모임방) · **모임방 만들기**(누구나)
- 방: 채팅 / 자료실(정렬·업로드) / 캘린더(금일·주간·월간, 일정 추가·수정·첨부)
- 병실 잔여 현황 메모(편집·게시)
- 관리자 콘솔(전체관리자): 멤버 목록 · 방 목록

## 주의
- Supabase SQL(`supabase/` 폴더) 설정이 먼저 되어 있어야 로그인·데이터가 동작합니다.
- 같은 계정으로 폰 앱과 웹을 함께 써도 됩니다 (백엔드 공유).
