-- ========================================
-- MacBroom Database Schema — Migration
-- Run this FIRST to drop old objects, then run the new schema
-- ========================================

-- 1. Drop old functions (signatures must match exactly)
DROP FUNCTION IF EXISTS activate_license(TEXT, TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS validate_license(TEXT) CASCADE;
DROP FUNCTION IF EXISTS generate_license(TEXT, TEXT, INT) CASCADE;
DROP FUNCTION IF EXISTS public.get_user_license(UUID) CASCADE;
DROP FUNCTION IF EXISTS public.link_license_to_user(TEXT, UUID) CASCADE;
DROP FUNCTION IF EXISTS public.get_subscription_status(UUID) CASCADE;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;

-- 2. Drop old tables
DROP TABLE IF EXISTS public.subscriptions CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;
DROP TABLE IF EXISTS public.licenses CASCADE;

-- 3. Drop old indexes (if they exist outside tables)
DROP INDEX IF EXISTS idx_licenses_key;
DROP INDEX IF EXISTS idx_licenses_email;
DROP INDEX IF EXISTS idx_licenses_status;
DROP INDEX IF EXISTS idx_profiles_email;
DROP INDEX IF EXISTS idx_profiles_user_id;
DROP INDEX IF EXISTS idx_subscriptions_user_id;
DROP INDEX IF EXISTS idx_subscriptions_status;
DROP INDEX IF EXISTS idx_licenses_user_id;

-- ========================================
-- NOW run supabase-schema.sql then supabase-auth-schema.sql
-- ========================================
