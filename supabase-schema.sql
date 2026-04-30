-- ========================================
-- MacBroom Database Schema
-- ========================================

-- 1. Licenses Table
DROP TABLE IF EXISTS licenses CASCADE;
CREATE TABLE licenses (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    license_key TEXT NOT NULL UNIQUE,
    email TEXT NOT NULL,
    plan TEXT NOT NULL DEFAULT 'free' CHECK (plan IN ('free', 'pro')),
    billing_cycle TEXT NOT NULL DEFAULT 'lifetime' CHECK (billing_cycle IN ('monthly', 'yearly', 'lifetime')),
    device_limit INT NOT NULL DEFAULT 1 CHECK (device_limit IN (1, 2)),
    status TEXT NOT NULL DEFAULT 'unused' CHECK (status IN ('active', 'expired', 'revoked', 'unused')),
    price_paid NUMERIC(10, 2),
    device_ids TEXT[] DEFAULT '{}',
    device_names TEXT[] DEFAULT '{}',
    activated_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Indexes
CREATE INDEX idx_licenses_key ON licenses(license_key);
CREATE INDEX idx_licenses_email ON licenses(email);
CREATE INDEX idx_licenses_status ON licenses(status);

-- 3. Function: Activate a license key
CREATE OR REPLACE FUNCTION activate_license(
    p_key TEXT,
    p_device_id TEXT,
    p_device_name TEXT
)
RETURNS TABLE (
    valid BOOLEAN,
    plan TEXT,
    billing_cycle TEXT,
    device_limit INT,
    email TEXT,
    expires_at TIMESTAMPTZ,
    message TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_license RECORD;
    v_device_count INT;
BEGIN
    SELECT * INTO v_license FROM licenses WHERE license_key = p_key;
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, 'free'::TEXT, 'lifetime'::TEXT, 1, ''::TEXT, NULL::TIMESTAMPTZ, 'License key not found'::TEXT;
        RETURN;
    END IF;
    
    IF v_license.status = 'revoked' THEN
        RETURN QUERY SELECT FALSE, 'free'::TEXT, 'lifetime'::TEXT, 1, ''::TEXT, NULL::TIMESTAMPTZ, 'License key has been revoked'::TEXT;
        RETURN;
    END IF;
    
    IF v_license.status = 'expired' OR (v_license.expires_at IS NOT NULL AND v_license.expires_at < NOW()) THEN
        UPDATE licenses SET status = 'expired' WHERE id = v_license.id;
        RETURN QUERY SELECT FALSE, 'free'::TEXT, 'lifetime'::TEXT, 1, ''::TEXT, v_license.expires_at, 'License has expired'::TEXT;
        RETURN;
    END IF;
    
    -- Check device limit
    v_device_count := array_length(v_license.device_ids, 1);
    IF v_device_count IS NULL THEN v_device_count := 0; END IF;
    
    -- Already activated on this device? OK
    IF p_device_id = ANY(v_license.device_ids) THEN
        -- Update last activated
        UPDATE licenses SET activated_at = NOW() WHERE id = v_license.id;
        RETURN QUERY SELECT 
            TRUE, 
            v_license.plan, 
            v_license.billing_cycle, 
            v_license.device_limit,
            v_license.email, 
            v_license.expires_at,
            'License activated successfully'::TEXT;
        RETURN;
    END IF;
    
    -- New device but limit reached
    IF v_device_count >= v_license.device_limit THEN
        RETURN QUERY SELECT FALSE, 'free'::TEXT, 'lifetime'::TEXT, 1, ''::TEXT, NULL::TIMESTAMPTZ, 
            'Device limit reached (' || v_license.device_limit || ' device' || 
            CASE WHEN v_license.device_limit > 1 THEN 's' ELSE '' END || ')'::TEXT;
        RETURN;
    END IF;
    
    -- Activate on new device
    UPDATE licenses 
    SET 
        status = 'active',
        device_ids = array_append(device_ids, p_device_id),
        device_names = array_append(device_names, p_device_name),
        activated_at = COALESCE(activated_at, NOW())
    WHERE id = v_license.id;
    
    RETURN QUERY SELECT 
        TRUE, 
        v_license.plan, 
        v_license.billing_cycle, 
        v_license.device_limit,
        v_license.email, 
        v_license.expires_at,
        'License activated successfully'::TEXT;
END;
$$;

-- 4. Function: Validate license for a device
CREATE OR REPLACE FUNCTION validate_license(
    p_device_id TEXT
)
RETURNS TABLE (
    valid BOOLEAN,
    plan TEXT,
    billing_cycle TEXT,
    device_limit INT,
    email TEXT,
    expires_at TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_license RECORD;
BEGIN
    SELECT * INTO v_license FROM licenses 
    WHERE p_device_id = ANY(device_ids) AND status = 'active'
    ORDER BY created_at DESC LIMIT 1;
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, 'free'::TEXT, 'lifetime'::TEXT, 1, ''::TEXT, NULL::TIMESTAMPTZ;
        RETURN;
    END IF;
    
    IF v_license.expires_at IS NOT NULL AND v_license.expires_at < NOW() THEN
        UPDATE licenses SET status = 'expired' WHERE id = v_license.id;
        RETURN QUERY SELECT FALSE, 'free'::TEXT, 'lifetime'::TEXT, 1, ''::TEXT, NULL::TIMESTAMPTZ;
        RETURN;
    END IF;
    
    RETURN QUERY SELECT 
        TRUE, 
        v_license.plan, 
        v_license.billing_cycle, 
        v_license.device_limit,
        v_license.email, 
        v_license.expires_at;
END;
$$;

-- 5. Function: Deactivate a specific device
CREATE OR REPLACE FUNCTION deactivate_device(
    p_key TEXT,
    p_device_id TEXT
)
RETURNS TABLE (
    success BOOLEAN,
    message TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_license RECORD;
    v_idx INT;
BEGIN
    SELECT * INTO v_license FROM licenses WHERE license_key = p_key;
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, 'License key not found'::TEXT;
        RETURN;
    END IF;
    
    IF NOT p_device_id = ANY(v_license.device_ids) THEN
        RETURN QUERY SELECT FALSE, 'Device not found on this license'::TEXT;
        RETURN;
    END IF;
    
    UPDATE licenses 
    SET 
        device_ids = array_remove(device_ids, p_device_id),
        device_names = array_remove(device_names, 
            v_license.device_names[array_position(v_license.device_ids, p_device_id)]
        )
    WHERE id = v_license.id;
    
    RETURN QUERY SELECT TRUE, 'Device deactivated successfully'::TEXT;
END;
$$;

-- 6. Function: Generate a license key
CREATE OR REPLACE FUNCTION generate_license(
    p_email TEXT,
    p_plan TEXT DEFAULT 'pro',
    p_billing_cycle TEXT DEFAULT 'lifetime',
    p_device_limit INT DEFAULT 1,
    p_price_paid NUMERIC DEFAULT 0,
    p_duration_days INT DEFAULT NULL
)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_key TEXT;
    v_expires TIMESTAMPTZ;
BEGIN
    -- Calculate expiry
    IF p_billing_cycle = 'monthly' THEN
        v_expires := NOW() + INTERVAL '30 days';
    ELSIF p_billing_cycle = 'yearly' THEN
        v_expires := NOW() + INTERVAL '365 days';
    ELSIF p_duration_days IS NOT NULL THEN
        v_expires := NOW() + (p_duration_days || ' days')::INTERVAL;
    ELSE
        v_expires := NULL; -- lifetime
    END IF;
    
    -- Generate key: MACBROOM-XXXX-XXXX-XXXX-XXXX
    v_key := 'MACBROOM-' || 
        upper(substring(md5(random()::text || clock_timestamp()::text) from 1 for 4)) || '-' ||
        upper(substring(md5(random()::text || clock_timestamp()::text) from 1 for 4)) || '-' ||
        upper(substring(md5(random()::text || clock_timestamp()::text) from 1 for 4)) || '-' ||
        upper(substring(md5(random()::text || clock_timestamp()::text) from 1 for 4));
    
    INSERT INTO licenses (license_key, email, plan, billing_cycle, device_limit, status, price_paid, expires_at)
    VALUES (v_key, p_email, p_plan, p_billing_cycle, p_device_limit, 'unused', p_price_paid, v_expires);
    
    RETURN v_key;
END;
$$;

-- 7. Enable RLS
ALTER TABLE licenses ENABLE ROW LEVEL SECURITY;

-- 8. RLS Policies
CREATE POLICY "Allow anonymous activation" ON licenses
    FOR ALL USING (true) WITH CHECK (true);

-- 9. Test licenses (remove in production)
-- SELECT generate_license('test@macbroom.com', 'pro', 'yearly', 1, 24.99);
-- SELECT generate_license('test@macbroom.com', 'pro', 'lifetime', 2, 59.99);
