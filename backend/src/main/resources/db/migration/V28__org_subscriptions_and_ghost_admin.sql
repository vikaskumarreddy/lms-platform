-- =====================================================================
-- V28: SaaS platform enhancements
--  * org_subscriptions   : plans assigned to organizations (e.g. platform only,
--                          platform + training support)
--  * organizations.org_subscription_id : link an org to its SaaS plan
--  * users.is_ghost      : marks the auto-created super-admin ghost user inside
--                          every tenant (admin@axisora.com), who is never shown
--                          in the tenant's admin list.
--  * users.email         : was globally UNIQUE; for multi-tenancy each tenant may
--                          contain the same ghost admin, so email becomes unique
--                          per (organization_id, email).
-- =====================================================================

-- Track whether a platform-level migration task has run for each org.
CREATE TABLE IF NOT EXISTS org_ghost_check (
    organization_id BIGINT PRIMARY KEY,
    ghost_created   BOOLEAN NOT NULL DEFAULT FALSE
);

-- 1) users: relax global email uniqueness to per-organization uniqueness
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_email_key;
ALTER TABLE users ADD CONSTRAINT uk_users_org_email UNIQUE (organization_id, email);

-- users: ghost flag used to hide the platform super-admin from tenant admin lists
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_ghost BOOLEAN NOT NULL DEFAULT FALSE;

-- 2) organizations: link to a SaaS org_subscriptions plan
ALTER TABLE organizations ADD COLUMN IF NOT EXISTS org_subscription_id BIGINT;

-- 3) org_subscriptions table + seed defaults
CREATE TABLE IF NOT EXISTS org_subscriptions (
    id           SERIAL PRIMARY KEY,
    name         VARCHAR(255) NOT NULL,
    description  TEXT,
    price        NUMERIC(12,2) NOT NULL DEFAULT 0,
    period       VARCHAR(20)  NOT NULL DEFAULT 'monthly', -- monthly | yearly | custom
    features     TEXT,          -- JSON array of included features
    is_active    BOOLEAN NOT NULL DEFAULT TRUE,
    is_popular   BOOLEAN NOT NULL DEFAULT FALSE,
    created_at   TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMP NOT NULL DEFAULT NOW()
);

INSERT INTO org_subscriptions (name, description, price, period, features, is_active, is_popular)
SELECT 'Platform Only', 'Access to the core LMS platform for your organization.', 0, 'monthly',
       '["Core LMS platform","Unlimited students","Unlimited courses","Email support"]', TRUE, FALSE
WHERE NOT EXISTS (SELECT 1 FROM org_subscriptions WHERE name = 'Platform Only');

INSERT INTO org_subscriptions (name, description, price, period, features, is_active, is_popular)
SELECT 'Platform + Training Support', 'Core platform plus hands-on training and implementation support.', 990, 'monthly',
       '["Core LMS platform","Unlimited students","Unlimited courses","Training support","Priority email support"]', TRUE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM org_subscriptions WHERE name = 'Platform + Training Support');

INSERT INTO org_subscriptions (name, description, price, period, features, is_active, is_popular)
SELECT 'Enterprise', 'Full platform with a dedicated manager, custom domain and SLA.', 2490, 'monthly',
       '["Core LMS platform","Unlimited everything","Dedicated manager","Custom domain","99.9% SLA","24/7 support"]', TRUE, FALSE
WHERE NOT EXISTS (SELECT 1 FROM org_subscriptions WHERE name = 'Enterprise');

-- 4) Mark the existing platform super admin as a ghost user
UPDATE users SET is_ghost = TRUE
WHERE email = 'admin@axisora.com' AND role = 'ADMIN';

-- 5) Populate org_ghost_check for all current orgs so the app-level logic only
--    takes over for newly-created organizations.
INSERT INTO org_ghost_check (organization_id, ghost_created)
SELECT id, TRUE FROM organizations
ON CONFLICT (organization_id) DO NOTHING;