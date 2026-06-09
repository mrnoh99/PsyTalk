# 구글 캘린더 양방향 동기화 설정 (GCAL_SYNC)

주간 학술활동 방 캘린더 ↔ 특정 **Google Calendar** 를 **양방향(2-way)** 으로
동기화합니다. 한쪽에서 만들고/고치고/지운 일정이 반대쪽에도 반영됩니다.

- **인증:** 서비스 계정(서버가 사용자 로그인 없이 읽기/쓰기)
- **충돌:** 마지막 수정 우선(last-write-wins)
- **첨부:** 공유 드라이브 폴더 경유(설정 시). 미설정이면 첨부만 건너뜀.
- **반복일정:** 개별 일정으로 취급(`singleEvents=true`)
- **종료시간:** 앱 일정엔 종료가 없어 구글에는 시작+1시간으로 표기

관련 파일: `supabase/gcal_sync.sql`, `supabase/functions/gcal-sync/index.ts`

---

## 1. Google Cloud 준비 (1회)

1. https://console.cloud.google.com 에서 **프로젝트 생성**(또는 기존 사용).
2. **API 및 서비스 → 라이브러리** 에서 다음을 "사용 설정":
   - **Google Calendar API**
   - (첨부 동기화를 쓸 경우) **Google Drive API**
3. **API 및 서비스 → 사용자 인증 정보 → 서비스 계정 만들기**.
   - 이름 입력 후 생성. 역할은 지정 안 해도 됨.
4. 만든 서비스 계정 → **키 → 키 추가 → 새 키 → JSON** → JSON 파일 다운로드.
   - 파일 안의 `client_email`, `private_key` 두 값을 곧 사용합니다.

## 2. 대상 캘린더 공유 (1회)

1. 동기화할 **Google 캘린더 설정 → 특정 사용자와 공유** 로 이동.
2. **서비스 계정 이메일**(`client_email`, `...@...iam.gserviceaccount.com`)을 추가하고
   권한을 **"변경 및 일정 관리"** 로 설정. (양방향 쓰기에 필수)
3. 같은 설정 화면의 **캘린더 통합 → 캘린더 ID** 를 복사(`...@group.calendar.google.com`).

## 3. (첨부 동기화 시) 공유 드라이브 폴더 (선택)

서비스 계정은 자체 Drive 용량이 없어 **공유 드라이브(Shared Drive)** 가 필요합니다(Google Workspace).
1. 공유 드라이브를 만들고 **서비스 계정 이메일을 멤버(콘텐츠 관리자)** 로 추가.
2. 그 안에 폴더를 만들고 URL 의 폴더 ID(`.../folders/<여기>`)를 복사 → `drive_folder_id`.
> 공유 드라이브가 없으면 이 단계를 건너뛰세요. 첨부만 동기화되지 않고 나머지는 정상 동작합니다.

## 4. Supabase Secrets (Edge Function 비밀값)

```bash
supabase secrets set GCAL_SA_EMAIL="<client_email>"
# private_key 는 줄바꿈(\n)이 포함되어 있습니다. 따옴표로 통째로 넣으세요.
supabase secrets set GCAL_SA_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
```
`SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` 는 런타임이 자동 주입하므로 설정 불필요.

## 5. SQL 실행

1. Supabase 대시보드 **Database → Extensions** 에서 `pg_net`, `pg_cron` 활성화.
2. SQL Editor 에서 **`supabase/gcal_sync.sql`** 실행.
3. 설정 행을 실제 값으로 갱신하고 켜기:
   ```sql
   update public.gcal_sync set
     google_calendar_id = '<캘린더 ID>',
     drive_folder_id    = '<공유 드라이브 폴더 ID 또는 NULL>',
     enabled            = true
   where room_id = '11111111-1111-1111-1111-111111110012';
   ```

## 6. Edge Function 배포

```bash
supabase functions deploy gcal-sync
# 수동 1회 동기화 테스트
supabase functions invoke gcal-sync
```
정상이면 `gcal_sync.last_status` 가 `ok ...` 로 갱신됩니다.

## 7. 자동 주기 동기화 (5분)

대시보드 **SQL Editor** 에서 (`<PROJECT_REF>` 와 `<KEY>` 만 본인 값으로):
- `<KEY>` 는 **anon 키**(공개)면 충분 — 함수가 내부에서 service_role 을 씁니다.

```sql
create extension if not exists pg_net;
create extension if not exists pg_cron;
do $$ begin perform cron.unschedule('moim_gcal_sync'); exception when others then null; end $$;
select cron.schedule('moim_gcal_sync', '*/5 * * * *', $cron$
  select net.http_post(
    url     := 'https://<PROJECT_REF>.functions.supabase.co/gcal-sync',
    headers := jsonb_build_object('Content-Type','application/json',
                                  'Authorization','Bearer <KEY>'),
    body    := '{}'::jsonb
  );
$cron$);
```

**즉시 1회 테스트**(5분 안 기다리고): 위 `select net.http_post(...)` 부분만 단독 실행 →
잠시 뒤 `select last_synced_at from gcal_sync;` 가 갱신되면 정상.

**진단(자동이 안 돌 때):**
```sql
select jobname, schedule, active from cron.job;                 -- 잡 존재?
select status, return_message, start_time from cron.job_run_details
  where jobid=(select jobid from cron.job where jobname='moim_gcal_sync')
  order by start_time desc limit 5;                             -- 실행됨/성공?
select status_code, created from net._http_response order by created desc limit 5; -- HTTP 200?
```
- 잡이 없으면 → 위 `cron.schedule` 가 실행 안 된 것(확장 미활성 등).
- `status_code` 가 401 → Authorization 키 오타. 200 → 정상.

---

## 동작 확인

| 시나리오 | 기대 결과 |
|---|---|
| 구글에서 일정 추가 | 다음 동기화에 앱 주간 학술활동에 등장(작성자=전체관리자) |
| 앱에서 일정 추가 | 다음 동기화에 구글 캘린더에 등장 |
| 양쪽에서 같은 일정 수정 | **나중에 고친 쪽** 값으로 수렴 |
| 한쪽에서 삭제 | 반대쪽에서도 삭제 |
| 첨부 추가(드라이브 설정 시) | 반대쪽에 파일 연결 |

## 문제 해결

- `last_status` 에 `error: ...` → 메시지 확인.
  - `토큰 발급 실패` → SA 이메일/키 또는 시계/`\n` 처리 확인.
  - `gapi 404` → 캘린더 ID 오타 또는 서비스 계정 공유 누락.
  - `gapi 403` → Calendar/Drive API 미사용설정 또는 공유 권한 부족.
- 첨부가 안 올라감 → 공유 드라이브 멤버/폴더 ID, Drive API 사용설정 확인(첨부는 best-effort).
- 동기화가 꼬였을 때 전체 재동기화: `update gcal_sync set sync_token=null where room_id='...';`
