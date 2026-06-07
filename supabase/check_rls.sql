-- =============================================================================
-- check_rls.sql — RLS(행 수준 보안) 점검용 1회 조회
--   웹은 anon(공개) key 를 코드에 노출하므로, 무단 접근을 막는 유일한 방어막이 RLS 다.
--   public 스키마 모든 테이블의 RLS 켜짐 여부 + 정책 수를 한 번에 확인.
--   ※ 읽기 전용(데이터 변경 없음). 안전하게 여러 번 실행 가능.
--
--   판정:
--     ❌ OFF(위험)            → 아무나 anon key 로 전체 행 읽기/쓰기 가능. 반드시 RLS 켜야 함.
--     ✅ ON / 정책수 ≥ 1      → 정상.
--     ⚠ ON 인데 정책수 0      → 그 테이블은 전면 차단(기능 오류). 해당 SQL 의 CREATE POLICY 실행 필요.
-- =============================================================================
SELECT t.relname                                   AS "테이블",
       CASE WHEN t.relrowsecurity THEN '✅ ON' ELSE '❌ OFF(위험)' END AS "RLS",
       count(p.policyname)                         AS "정책수",
       CASE
         WHEN NOT t.relrowsecurity THEN '🚨 anon 으로 전체 노출 — RLS 켜기 필요'
         WHEN t.relrowsecurity AND count(p.policyname)=0 THEN '⚠ RLS는 켰는데 정책 없음 → 전면 차단(기능 오류)'
         ELSE ''
       END                                         AS "비고"
FROM pg_class t
JOIN pg_namespace n ON n.oid = t.relnamespace
LEFT JOIN pg_policies p ON p.schemaname = 'public' AND p.tablename = t.relname
WHERE n.nspname = 'public' AND t.relkind = 'r'
GROUP BY t.relname, t.relrowsecurity
ORDER BY t.relrowsecurity ASC, t.relname;

-- 핵심 테이블이 모두 ✅ ON 인지 특히 확인:
--   profiles · rooms · room_members · messages · message_reactions · calendar_events
--   room_files · room_reads · room_pins · room_writers · ward_status · ward_duty · message_cross_posts
--
-- ❌ OFF 인 테이블이 있으면, 해당 테이블을 만든 *.sql 을 다시 실행하거나(정책 포함),
-- 급한 경우 아래처럼 켠 뒤 그 테이블의 CREATE POLICY 부분을 반드시 함께 실행:
--   ALTER TABLE public.<테이블> ENABLE ROW LEVEL SECURITY;
-- (정책 없이 RLS만 켜면 전면 차단되니 정책과 함께 적용)
-- =============================================================================
