-- =============================================================================
-- "Database error creating new user" / enum member_type 오류 해결
-- Supabase Dashboard → SQL Editor → Run
--
-- member_type 이 ENUM 인 경우, 허용 값은 아래로 확인:
--   SELECT enumlabel FROM pg_enum e
--   JOIN pg_type t ON e.enumtypid = t.oid
--   WHERE t.typname = 'member_type' ORDER BY e.enumsortorder;
-- =============================================================================

-- ── 헬퍼: enum 첫 번째 라벨 ──
CREATE OR REPLACE FUNCTION public._first_enum_label(type_name text)
RETURNS text
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT e.enumlabel::text
  FROM pg_enum e
  JOIN pg_type t ON e.enumtypid = t.oid
  JOIN pg_namespace n ON t.typnamespace = n.oid
  WHERE t.typname = type_name
    AND n.nspname = 'public'
  ORDER BY e.enumsortorder
  LIMIT 1;
$$;

-- ── 헬퍼: preferred 목록 중 존재하는 값, 없으면 첫 번째 ──
CREATE OR REPLACE FUNCTION public._enum_label_prefer(type_name text, preferred text[])
RETURNS text
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
  p text;
  lbl text;
BEGIN
  FOREACH p IN ARRAY preferred LOOP
    SELECT e.enumlabel INTO lbl
    FROM pg_enum e
    JOIN pg_type t ON e.enumtypid = t.oid
    JOIN pg_namespace n ON t.typnamespace = n.oid
    WHERE t.typname = type_name
      AND n.nspname = 'public'
      AND e.enumlabel = p;
    IF lbl IS NOT NULL THEN
      RETURN lbl;
    END IF;
  END LOOP;
  RETURN public._first_enum_label(type_name);
END;
$$;

-- ── 1) profiles: NULL 행 보정 (ENUM/text 모두 대응) ──
DO $$
DECLARE
  mt_udt text;
  role_udt text;
  mt_default text;
  role_default text;
  mt_is_enum boolean;
  role_is_enum boolean;
BEGIN
  SELECT udt_name INTO mt_udt
  FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'member_type';

  SELECT udt_name INTO role_udt
  FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'role';

  mt_is_enum := EXISTS (
    SELECT 1 FROM pg_type t
    JOIN pg_namespace n ON t.typnamespace = n.oid
    WHERE n.nspname = 'public' AND t.typname = mt_udt AND t.typtype = 'e'
  );

  role_is_enum := EXISTS (
    SELECT 1 FROM pg_type t
    JOIN pg_namespace n ON t.typnamespace = n.oid
    WHERE n.nspname = 'public' AND t.typname = role_udt AND t.typtype = 'e'
  );

  UPDATE public.profiles SET name = COALESCE(name, '') WHERE name IS NULL;

  IF mt_is_enum THEN
    mt_default := public._enum_label_prefer(
      mt_udt,
      ARRAY['교실', 'resident', 'trainee', 'staff', 'faculty', 'doctor', 'member', 'user']
    );
    EXECUTE format(
      'UPDATE public.profiles SET member_type = %L::%I WHERE member_type IS NULL',
      mt_default, mt_udt
    );
  ELSIF mt_udt IS NOT NULL THEN
    UPDATE public.profiles
    SET member_type = COALESCE(member_type, 'user')
    WHERE member_type IS NULL;
  END IF;

  IF role_is_enum THEN
    role_default := public._enum_label_prefer(
      role_udt,
      ARRAY['user', 'member', 'staff']
    );
    EXECUTE format(
      'UPDATE public.profiles SET role = %L::%I WHERE role IS NULL',
      role_default, role_udt
    );
  ELSIF role_udt IS NOT NULL THEN
    UPDATE public.profiles
    SET role = COALESCE(role, 'user')
    WHERE role IS NULL;
  END IF;
END;
$$;

-- text 컬럼일 때만 기본값 설정 (enum 컬럼에 'member' 기본값 넣지 않음)
DO $$
DECLARE
  mt_udt text;
  role_udt text;
BEGIN
  SELECT udt_name INTO mt_udt
  FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'member_type';

  SELECT udt_name INTO role_udt
  FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'role';

  IF NOT EXISTS (
    SELECT 1 FROM pg_type t JOIN pg_namespace n ON t.typnamespace = n.oid
    WHERE n.nspname = 'public' AND t.typname = mt_udt AND t.typtype = 'e'
  ) THEN
    ALTER TABLE public.profiles ALTER COLUMN member_type SET DEFAULT 'user';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_type t JOIN pg_namespace n ON t.typnamespace = n.oid
    WHERE n.nspname = 'public' AND t.typname = role_udt AND t.typtype = 'e'
  ) THEN
    ALTER TABLE public.profiles ALTER COLUMN role SET DEFAULT 'user';
  END IF;
EXCEPTION
  WHEN others THEN
    RAISE NOTICE 'DEFAULT 설정 건너뜀: %', SQLERRM;
END;
$$;

-- ── 2) 권한·RLS ──
GRANT USAGE ON SCHEMA public TO supabase_auth_admin;
GRANT ALL ON TABLE public.profiles TO supabase_auth_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.profiles TO authenticated;
GRANT SELECT ON TABLE public.profiles TO anon;

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "profiles_select_own" ON public.profiles;
CREATE POLICY "profiles_select_own"
  ON public.profiles FOR SELECT TO authenticated
  USING (auth.uid() = id);

DROP POLICY IF EXISTS "profiles_insert_own" ON public.profiles;
CREATE POLICY "profiles_insert_own"
  ON public.profiles FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = id);

-- ── 3) 트리거 (ENUM 기본값 자동 선택) ──
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  display_name text;
  mt_udt text;
  role_udt text;
  mt_val text;
  role_val text;
  meta_mt text;
  meta_role text;
BEGIN
  display_name := COALESCE(
    NULLIF(trim(NEW.raw_user_meta_data ->> 'name'), ''),
    NULLIF(trim(NEW.raw_user_meta_data ->> 'full_name'), ''),
    split_part(COALESCE(NEW.email, ''), '@', 1),
    'user'
  );

  meta_mt := NULLIF(trim(NEW.raw_user_meta_data ->> 'member_type'), '');
  meta_role := NULLIF(trim(NEW.raw_user_meta_data ->> 'role'), '');

  SELECT udt_name INTO mt_udt
  FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'member_type';

  SELECT udt_name INTO role_udt
  FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'role';

  IF EXISTS (
    SELECT 1 FROM pg_type t JOIN pg_namespace n ON t.typnamespace = n.oid
    WHERE n.nspname = 'public' AND t.typname = mt_udt AND t.typtype = 'e'
  ) THEN
    IF meta_mt IS NOT NULL AND EXISTS (
      SELECT 1 FROM pg_enum e
      JOIN pg_type t ON e.enumtypid = t.oid
      WHERE t.typname = mt_udt AND e.enumlabel = meta_mt
    ) THEN
      mt_val := meta_mt;
    ELSE
      mt_val := public._enum_label_prefer(
        mt_udt,
        ARRAY['교실', 'resident', 'trainee', 'staff', 'faculty', 'doctor', 'member', 'user']
      );
    END IF;
  ELSE
    mt_val := COALESCE(meta_mt, 'user');
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_type t JOIN pg_namespace n ON t.typnamespace = n.oid
    WHERE n.nspname = 'public' AND t.typname = role_udt AND t.typtype = 'e'
  ) THEN
    IF meta_role IS NOT NULL AND EXISTS (
      SELECT 1 FROM pg_enum e
      JOIN pg_type t ON e.enumtypid = t.oid
      WHERE t.typname = role_udt AND e.enumlabel = meta_role
    ) THEN
      role_val := meta_role;
    ELSE
      role_val := public._enum_label_prefer(role_udt, ARRAY['user', 'member', 'staff']);
    END IF;
  ELSE
    role_val := COALESCE(meta_role, 'user');
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_type t JOIN pg_namespace n ON t.typnamespace = n.oid
    WHERE n.nspname = 'public' AND t.typname = mt_udt AND t.typtype = 'e'
  ) AND EXISTS (
    SELECT 1 FROM pg_type t JOIN pg_namespace n ON t.typnamespace = n.oid
    WHERE n.nspname = 'public' AND t.typname = role_udt AND t.typtype = 'e'
  ) THEN
    EXECUTE format(
      'INSERT INTO public.profiles (id, name, member_type, role)
       VALUES (%L, %L, %L::%I, %L::%I)
       ON CONFLICT (id) DO NOTHING',
      NEW.id, display_name, mt_val, mt_udt, role_val, role_udt
    );
  ELSIF EXISTS (
    SELECT 1 FROM pg_type t JOIN pg_namespace n ON t.typnamespace = n.oid
    WHERE n.nspname = 'public' AND t.typname = mt_udt AND t.typtype = 'e'
  ) THEN
    EXECUTE format(
      'INSERT INTO public.profiles (id, name, member_type, role)
       VALUES (%L, %L, %L::%I, %L)
       ON CONFLICT (id) DO NOTHING',
      NEW.id, display_name, mt_val, mt_udt, role_val
    );
  ELSIF EXISTS (
    SELECT 1 FROM pg_type t JOIN pg_namespace n ON t.typnamespace = n.oid
    WHERE n.nspname = 'public' AND t.typname = role_udt AND t.typtype = 'e'
  ) THEN
    EXECUTE format(
      'INSERT INTO public.profiles (id, name, member_type, role)
       VALUES (%L, %L, %L, %L::%I)
       ON CONFLICT (id) DO NOTHING',
      NEW.id, display_name, mt_val, role_val, role_udt
    );
  ELSE
    INSERT INTO public.profiles (id, name, member_type, role)
    VALUES (NEW.id, display_name, mt_val, role_val)
    ON CONFLICT (id) DO NOTHING;
  END IF;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'handle_new_user failed for %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$;

ALTER FUNCTION public.handle_new_user() OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO supabase_auth_admin;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- ── 4) auth 사용자 → profiles 백필 ──
DO $$
DECLARE
  mt_udt text;
  role_udt text;
  mt_val text;
  role_val text;
  r record;
BEGIN
  SELECT udt_name INTO mt_udt
  FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'member_type';

  SELECT udt_name INTO role_udt
  FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'role';

  IF EXISTS (
    SELECT 1 FROM pg_type t JOIN pg_namespace n ON t.typnamespace = n.oid
    WHERE n.nspname = 'public' AND t.typname = mt_udt AND t.typtype = 'e'
  ) THEN
    mt_val := public._enum_label_prefer(
      mt_udt,
      ARRAY['교실', 'resident', 'trainee', 'staff', 'faculty', 'doctor', 'member', 'user']
    );
  ELSE
    mt_val := 'user';
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_type t JOIN pg_namespace n ON t.typnamespace = n.oid
    WHERE n.nspname = 'public' AND t.typname = role_udt AND t.typtype = 'e'
  ) THEN
    role_val := public._enum_label_prefer(role_udt, ARRAY['user', 'member', 'staff']);
  ELSE
    role_val := 'user';
  END IF;

  FOR r IN
    SELECT u.id, COALESCE(split_part(u.email, '@', 1), 'user') AS uname
    FROM auth.users u
    LEFT JOIN public.profiles p ON p.id = u.id
    WHERE p.id IS NULL
  LOOP
    IF EXISTS (
      SELECT 1 FROM pg_type t JOIN pg_namespace n ON t.typnamespace = n.oid
      WHERE n.nspname = 'public' AND t.typname = mt_udt AND t.typtype = 'e'
    ) AND EXISTS (
      SELECT 1 FROM pg_type t JOIN pg_namespace n ON t.typnamespace = n.oid
      WHERE n.nspname = 'public' AND t.typname = role_udt AND t.typtype = 'e'
    ) THEN
      EXECUTE format(
        'INSERT INTO public.profiles (id, name, member_type, role)
         VALUES (%L, %L, %L::%I, %L::%I) ON CONFLICT (id) DO NOTHING',
        r.id, r.uname, mt_val, mt_udt, role_val, role_udt
      );
    ELSIF EXISTS (
      SELECT 1 FROM pg_type t JOIN pg_namespace n ON t.typnamespace = n.oid
      WHERE n.nspname = 'public' AND t.typname = mt_udt AND t.typtype = 'e'
    ) THEN
      EXECUTE format(
        'INSERT INTO public.profiles (id, name, member_type, role)
         VALUES (%L, %L, %L::%I, %L) ON CONFLICT (id) DO NOTHING',
        r.id, r.uname, mt_val, mt_udt, role_val
      );
    ELSIF EXISTS (
      SELECT 1 FROM pg_type t JOIN pg_namespace n ON t.typnamespace = n.oid
      WHERE n.nspname = 'public' AND t.typname = role_udt AND t.typtype = 'e'
    ) THEN
      EXECUTE format(
        'INSERT INTO public.profiles (id, name, member_type, role)
         VALUES (%L, %L, %L, %L::%I) ON CONFLICT (id) DO NOTHING',
        r.id, r.uname, mt_val, role_val, role_udt
      );
    ELSE
      INSERT INTO public.profiles (id, name, member_type, role)
      VALUES (r.id, r.uname, mt_val, role_val)
      ON CONFLICT (id) DO NOTHING;
    END IF;
  END LOOP;
END;
$$;
