-- =============================================================================
-- add_member_types.sql — 직군(member_type) 값 추가
--   비서 · 의국동문 · 심리실 동문 · 기타
-- -----------------------------------------------------------------------------
-- member_type 이 ENUM 인 경우에만 필요합니다(이 프로젝트 기본).
-- 컬럼이 TEXT 라면 SQL 없이 앱의 직군 목록만으로 바로 동작합니다.
-- PostgreSQL 12+ (Supabase) 에서는 아래를 한 번에 실행해도 됩니다.
-- 실행: Supabase SQL Editor
-- =============================================================================

ALTER TYPE public.member_type ADD VALUE IF NOT EXISTS '생명사랑';
ALTER TYPE public.member_type ADD VALUE IF NOT EXISTS '비서';
ALTER TYPE public.member_type ADD VALUE IF NOT EXISTS '의국동문';
ALTER TYPE public.member_type ADD VALUE IF NOT EXISTS '심리실 동문';
ALTER TYPE public.member_type ADD VALUE IF NOT EXISTS '기타';

-- 확인:
--   SELECT enumlabel FROM pg_enum e JOIN pg_type t ON e.enumtypid = t.oid
--   WHERE t.typname = 'member_type' ORDER BY e.enumsortorder;
