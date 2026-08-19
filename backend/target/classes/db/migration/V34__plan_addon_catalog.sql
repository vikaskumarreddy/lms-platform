-- =====================================================================
-- V34: Configurable add-on catalog.
--
-- Add-ons are platform-level product definitions (like org_subscriptions,
-- deliberately without organization_id / @TenantId so the super admin can read
-- them through JPA). What a tenant actually buys is recorded separately in
-- org_subscription_addons, created in V35 once subscription instances exist.
--
-- Two columns do the real work:
--   * increments_limit_key   -> raises a LimitKey allowance (extra seats, storage)
--   * grants_entitlement_key -> switches on an Entitlement (API access, premium support)
-- so EntitlementService can resolve effective limits as
--   plan snapshot + sum(active add-ons) + per-tenant overrides
-- without any add-on-specific branching.
--
-- Prices are stored as a min/max band with a default, because the commercial
-- rates were specified as ranges. The band is enforced when a price is entered,
-- which keeps discounting inside agreed limits without a code change.
-- =====================================================================

CREATE TABLE IF NOT EXISTS plan_addons (
    id                     SERIAL PRIMARY KEY,
    code                   VARCHAR(60)  NOT NULL,
    name                   VARCHAR(160) NOT NULL,
    description            TEXT,

    -- CAPACITY | COMMUNICATION | SERVICES | INFRA | SUPPORT | TRAINING
    category               VARCHAR(30)  NOT NULL,

    -- PER_UNIT_MONTH : recurring, quantity x unit price each period (extra seats)
    -- PER_UNIT_ONCE  : one-off, quantity x unit price (credit packs, training hours)
    -- FLAT_MONTH     : recurring flat fee (API access, premium support)
    -- FLAT_ONCE      : one-off flat fee (a custom report, advanced migration)
    -- METERED        : billed from measured usage after the fact (gateway fees)
    -- QUOTED         : no list price; sales raises a quotation
    pricing_model          VARCHAR(20)  NOT NULL,

    unit_label             VARCHAR(60),
    unit_price_min         NUMERIC(12,2),
    unit_price_max         NUMERIC(12,2),
    default_unit_price     NUMERIC(12,2),

    min_qty                INT          NOT NULL DEFAULT 1,
    max_qty                INT,
    qty_increment          INT          NOT NULL DEFAULT 1,

    -- Must match com.institute.lms.subscription.LimitKey / Entitlement constants.
    increments_limit_key   VARCHAR(60),
    grants_entitlement_key VARCHAR(60),

    -- JSON array of plan codes this add-on may be attached to; NULL means any plan.
    applies_to_plan_codes  TEXT,

    -- TRUE when the add-on cannot be self-served and needs a quotation first.
    requires_quote         BOOLEAN      NOT NULL DEFAULT FALSE,
    -- How it is actually delivered. Shown to the platform team, not the tenant.
    fulfilment_notes       TEXT,

    hsn_sac_code           VARCHAR(10),
    gst_rate_pct           NUMERIC(5,2) NOT NULL DEFAULT 18.00,
    tax_inclusive          BOOLEAN      NOT NULL DEFAULT FALSE,

    is_active              BOOLEAN      NOT NULL DEFAULT TRUE,
    display_order          INT          NOT NULL DEFAULT 0,
    created_at             TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at             TIMESTAMP    NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uk_plan_addons_code ON plan_addons (code);
CREATE INDEX IF NOT EXISTS idx_plan_addons_active ON plan_addons (is_active, category, display_order);

ALTER TABLE plan_addons DROP CONSTRAINT IF EXISTS ck_plan_addons_price_band;
ALTER TABLE plan_addons ADD CONSTRAINT ck_plan_addons_price_band
    CHECK (unit_price_min IS NULL OR unit_price_max IS NULL OR unit_price_min <= unit_price_max);

-- =====================================================================
-- Seeds. Idempotent on code so re-running is safe.
-- =====================================================================

-- ---- CAPACITY -------------------------------------------------------
--
-- EXTRA_ACTIVE_STUDENTS: default_unit_price is 40, the top of the 15-40 band,
-- NOT the bottom. At 15/student an academy with 500 students would pay
-- 4,999 + 300*15 = 9,499 on Platform against 12,999 for Platform Plus, so the
-- add-on would make the recommended tier strictly worse value and capacity
-- would never drive an upgrade. org_subscriptions.overage_student_price holds
-- the per-plan rate (40 / 30 / 20) and takes precedence over this default;
-- overage_students_allowed caps how many can be stacked before an upgrade is
-- required.
INSERT INTO plan_addons (code, name, description, category, pricing_model, unit_label,
    unit_price_min, unit_price_max, default_unit_price, min_qty, max_qty, qty_increment,
    increments_limit_key, applies_to_plan_codes, requires_quote, fulfilment_notes,
    hsn_sac_code, display_order)
SELECT 'EXTRA_ACTIVE_STUDENTS', 'Additional active students',
    'Raises your active-student allowance. Billed per additional active student per month.',
    'CAPACITY', 'PER_UNIT_MONTH', 'active student',
    15.00, 40.00, 40.00, 10, NULL, 10,
    'MAX_ACTIVE_STUDENTS', NULL, FALSE,
    'The effective rate comes from the plan''s overage_student_price (Platform 40, Plus 30, Managed 20) so that buying the next tier is always cheaper than stacking seats. overage_students_allowed caps the quantity.',
    '997331', 1
WHERE NOT EXISTS (SELECT 1 FROM plan_addons WHERE code = 'EXTRA_ACTIVE_STUDENTS');

INSERT INTO plan_addons (code, name, description, category, pricing_model, unit_label,
    unit_price_min, unit_price_max, default_unit_price, min_qty, max_qty, qty_increment,
    increments_limit_key, hsn_sac_code, display_order)
SELECT 'EXTRA_FACULTY_ACCOUNTS', 'Additional faculty seats',
    'Extra faculty logins beyond your plan allowance. A faculty seat is a platform login and is not the same thing as a purchased training hour.',
    'CAPACITY', 'PER_UNIT_MONTH', 'faculty seat',
    300.00, 600.00, 499.00, 1, NULL, 1,
    'MAX_FACULTY_ACCOUNTS', '997331', 2
WHERE NOT EXISTS (SELECT 1 FROM plan_addons WHERE code = 'EXTRA_FACULTY_ACCOUNTS');

-- Restricted to plans carrying MULTI_BRANCH: selling a branch to a single-branch
-- Platform tenant would grant capacity for a feature they cannot use.
INSERT INTO plan_addons (code, name, description, category, pricing_model, unit_label,
    unit_price_min, unit_price_max, default_unit_price, min_qty, max_qty, qty_increment,
    increments_limit_key, applies_to_plan_codes, hsn_sac_code, display_order)
SELECT 'EXTRA_BRANCH', 'Additional branch',
    'An additional branch or campus under the same organization, sharing one student and course base.',
    'CAPACITY', 'PER_UNIT_MONTH', 'branch',
    1500.00, 3000.00, 1999.00, 1, NULL, 1,
    'MAX_BRANCHES', '["PLATFORM_PLUS","MANAGED_ACADEMY","ENTERPRISE"]', '997331', 3
WHERE NOT EXISTS (SELECT 1 FROM plan_addons WHERE code = 'EXTRA_BRANCH');

INSERT INTO plan_addons (code, name, description, category, pricing_model, unit_label,
    unit_price_min, unit_price_max, default_unit_price, min_qty, max_qty, qty_increment,
    increments_limit_key, hsn_sac_code, display_order)
SELECT 'EXTRA_STORAGE', 'Additional storage',
    'Extra storage for recordings, notes and learning materials.',
    'CAPACITY', 'PER_UNIT_MONTH', 'GB',
    20.00, 50.00, 30.00, 10, NULL, 10,
    'STORAGE_GB', '997331', 4
WHERE NOT EXISTS (SELECT 1 FROM plan_addons WHERE code = 'EXTRA_STORAGE');

-- ---- INFRA ----------------------------------------------------------
INSERT INTO plan_addons (code, name, description, category, pricing_model, unit_label,
    unit_price_min, unit_price_max, default_unit_price, min_qty, qty_increment,
    grants_entitlement_key, hsn_sac_code, display_order)
SELECT 'VIDEO_HOSTING_BANDWIDTH', 'Video hosting and bandwidth',
    'Hosted video delivery for recorded classes, billed on bandwidth served.',
    'INFRA', 'PER_UNIT_MONTH', 'GB bandwidth',
    8.00, 20.00, 12.00, 50, 50,
    'VIDEO_HOSTING', '998365', 10
WHERE NOT EXISTS (SELECT 1 FROM plan_addons WHERE code = 'VIDEO_HOSTING_BANDWIDTH');

INSERT INTO plan_addons (code, name, description, category, pricing_model, unit_label,
    unit_price_min, unit_price_max, default_unit_price, min_qty,
    grants_entitlement_key, hsn_sac_code, display_order)
SELECT 'API_ACCESS', 'API access',
    'Authenticated REST access to your organization''s data for reporting or integration with your own systems.',
    'INFRA', 'FLAT_MONTH', 'month',
    2500.00, 10000.00, 4999.00, 1,
    'API_ACCESS', '997331', 11
WHERE NOT EXISTS (SELECT 1 FROM plan_addons WHERE code = 'API_ACCESS');

-- Pass-through, not margin. Recorded as METERED so it is billed from measured
-- collections after the fact rather than charged up front.
INSERT INTO plan_addons (code, name, description, category, pricing_model, unit_label,
    unit_price_min, unit_price_max, default_unit_price, min_qty,
    hsn_sac_code, fulfilment_notes, display_order)
SELECT 'PAYMENT_GATEWAY_FEES', 'Payment gateway charges',
    'Payment gateway charges on fees collected through the platform, passed through at cost.',
    'INFRA', 'METERED', '% of collections',
    2.00, 3.00, 2.50, 1,
    '997158', 'Pass-through of the gateway''s own charge — carries no margin. Billed in arrears from measured collections, so it cannot be invoiced until a gateway is actually integrated.', 12
WHERE NOT EXISTS (SELECT 1 FROM plan_addons WHERE code = 'PAYMENT_GATEWAY_FEES');

-- SSO and dedicated infrastructure are quoted, never self-served: neither exists
-- in the platform today (auth is local JWT only; tenancy is shared-schema on a
-- single database). They are catalogued so a deal can record them, with the
-- delivery reality stated for whoever picks up the work.
INSERT INTO plan_addons (code, name, description, category, pricing_model,
    requires_quote, grants_entitlement_key, applies_to_plan_codes, fulfilment_notes,
    hsn_sac_code, display_order)
SELECT 'SSO_SETUP', 'Single sign-on integration',
    'SAML or OIDC single sign-on against your identity provider.',
    'INFRA', 'QUOTED',
    TRUE, 'SSO', '["ENTERPRISE"]',
    'Not implemented: authentication is local JWT only, with no SAML/OIDC support. Requires engineering scoping and a delivery date before this is committed to a customer.',
    '998314', 13
WHERE NOT EXISTS (SELECT 1 FROM plan_addons WHERE code = 'SSO_SETUP');

INSERT INTO plan_addons (code, name, description, category, pricing_model,
    requires_quote, grants_entitlement_key, applies_to_plan_codes, fulfilment_notes,
    hsn_sac_code, display_order)
SELECT 'DEDICATED_INFRASTRUCTURE', 'Dedicated infrastructure',
    'An isolated deployment with dedicated compute and database for your organization.',
    'INFRA', 'QUOTED',
    TRUE, 'DEDICATED_INFRASTRUCTURE', '["ENTERPRISE"]',
    'This is a separate deployment and an ongoing operational commitment, not a configuration flag — the platform is shared-schema on one database. Price must cover recurring infrastructure and maintenance, not just setup.',
    '998315', 14
WHERE NOT EXISTS (SELECT 1 FROM plan_addons WHERE code = 'DEDICATED_INFRASTRUCTURE');

-- ---- COMMUNICATION (prepaid credit packs) ---------------------------
INSERT INTO plan_addons (code, name, description, category, pricing_model, unit_label,
    unit_price_min, unit_price_max, default_unit_price, min_qty, qty_increment,
    hsn_sac_code, display_order)
SELECT 'SMS_CREDITS', 'SMS credits',
    'Prepaid SMS credits for attendance alerts, fee reminders and placement notifications.',
    'COMMUNICATION', 'PER_UNIT_ONCE', 'SMS',
    0.15, 0.30, 0.20, 1000, 1000,
    '998422', 20
WHERE NOT EXISTS (SELECT 1 FROM plan_addons WHERE code = 'SMS_CREDITS');

INSERT INTO plan_addons (code, name, description, category, pricing_model, unit_label,
    unit_price_min, unit_price_max, default_unit_price, min_qty, qty_increment,
    hsn_sac_code, display_order)
SELECT 'WHATSAPP_CREDITS', 'WhatsApp credits',
    'Prepaid WhatsApp Business message credits.',
    'COMMUNICATION', 'PER_UNIT_ONCE', 'message',
    0.60, 1.20, 0.85, 1000, 1000,
    '998422', 21
WHERE NOT EXISTS (SELECT 1 FROM plan_addons WHERE code = 'WHATSAPP_CREDITS');

INSERT INTO plan_addons (code, name, description, category, pricing_model, unit_label,
    unit_price_min, unit_price_max, default_unit_price, min_qty, qty_increment,
    hsn_sac_code, display_order)
SELECT 'EMAIL_CREDITS', 'Email credits',
    'Prepaid transactional email credits.',
    'COMMUNICATION', 'PER_UNIT_ONCE', 'email',
    0.05, 0.15, 0.08, 5000, 5000,
    '998422', 22
WHERE NOT EXISTS (SELECT 1 FROM plan_addons WHERE code = 'EMAIL_CREDITS');

-- ---- SERVICES -------------------------------------------------------
INSERT INTO plan_addons (code, name, description, category, pricing_model, unit_label,
    unit_price_min, unit_price_max, default_unit_price, min_qty,
    grants_entitlement_key, hsn_sac_code, display_order)
SELECT 'CUSTOM_REPORT', 'Custom report',
    'A report built to your specification and added to your reports section.',
    'SERVICES', 'FLAT_ONCE', 'report',
    5000.00, 25000.00, 12000.00, 1,
    'CUSTOM_REPORTS', '998314', 30
WHERE NOT EXISTS (SELECT 1 FROM plan_addons WHERE code = 'CUSTOM_REPORT');

INSERT INTO plan_addons (code, name, description, category, pricing_model,
    unit_price_min, unit_price_max, default_unit_price, min_qty,
    grants_entitlement_key, hsn_sac_code, fulfilment_notes, display_order)
SELECT 'ADVANCED_DATA_MIGRATION', 'Advanced data migration',
    'Migration beyond the records included in your plan, including cleansing and mapping from your existing system.',
    'SERVICES', 'FLAT_ONCE',
    15000.00, 75000.00, 25000.00, 1,
    'DATA_MIGRATION_FULL', '998314',
    'Scope against the plan''s MIGRATION_RECORDS_INCLUDED entitlement — this add-on covers the excess, so quote from the actual record count and source format.', 31
WHERE NOT EXISTS (SELECT 1 FROM plan_addons WHERE code = 'ADVANCED_DATA_MIGRATION');

INSERT INTO plan_addons (code, name, description, category, pricing_model, unit_label,
    unit_price_min, unit_price_max, default_unit_price, min_qty,
    hsn_sac_code, display_order)
SELECT 'CONTENT_CREATION', 'Content creation',
    'We produce course content — lessons, notes, question banks and assessments — to your syllabus.',
    'SERVICES', 'PER_UNIT_ONCE', 'course module',
    5000.00, 30000.00, 12000.00, 1,
    '999293', 32
WHERE NOT EXISTS (SELECT 1 FROM plan_addons WHERE code = 'CONTENT_CREATION');

INSERT INTO plan_addons (code, name, description, category, pricing_model,
    unit_price_min, unit_price_max, default_unit_price, min_qty, requires_quote,
    hsn_sac_code, fulfilment_notes, display_order)
SELECT 'CUSTOM_WEBSITE_WORK', 'Custom website work',
    'Website work beyond the pages and revisions included in your plan — bespoke design, extra sections or integrations.',
    'SERVICES', 'QUOTED',
    20000.00, 150000.00, 45000.00, 1, TRUE,
    '998314',
    'Quote against the plan''s WEBSITE_PAGES_INCLUDED / WEBSITE_REVISIONS_INCLUDED / MAINTENANCE_HOURS_PER_QUARTER entitlements so it is clear what the subscription already covers.', 33
WHERE NOT EXISTS (SELECT 1 FROM plan_addons WHERE code = 'CUSTOM_WEBSITE_WORK');

INSERT INTO plan_addons (code, name, description, category, pricing_model,
    requires_quote, grants_entitlement_key, hsn_sac_code, fulfilment_notes, display_order)
SELECT 'BRANDED_MOBILE_APP', 'Custom branded Android and iOS apps',
    'Your own branded student apps published under your developer accounts.',
    'SERVICES', 'QUOTED',
    TRUE, 'WHITE_LABEL_MOBILE_APP', '998314',
    'Cannot be self-served: needs a per-tenant Flutter build with its own applicationId/bundleId, signing keys, store listings and review cycles, plus a rebuild for every future release. Price the recurring release burden, not just the first build.', 34
WHERE NOT EXISTS (SELECT 1 FROM plan_addons WHERE code = 'BRANDED_MOBILE_APP');

INSERT INTO plan_addons (code, name, description, category, pricing_model,
    requires_quote, grants_entitlement_key, hsn_sac_code, display_order)
SELECT 'CUSTOM_INTEGRATION', 'Custom integration',
    'Integration with your ERP, accounting, CRM or identity systems.',
    'SERVICES', 'QUOTED',
    TRUE, 'CUSTOM_INTEGRATIONS', '998314', 35
WHERE NOT EXISTS (SELECT 1 FROM plan_addons WHERE code = 'CUSTOM_INTEGRATION');

-- ---- SUPPORT --------------------------------------------------------
INSERT INTO plan_addons (code, name, description, category, pricing_model, unit_label,
    unit_price_min, unit_price_max, default_unit_price, min_qty,
    grants_entitlement_key, hsn_sac_code, display_order)
SELECT 'PREMIUM_SUPPORT', 'Premium support',
    'Faster response targets, an escalation path and a named contact.',
    'SUPPORT', 'FLAT_MONTH', 'month',
    5000.00, 20000.00, 9999.00, 1,
    'PREMIUM_SUPPORT', '997331', 40
WHERE NOT EXISTS (SELECT 1 FROM plan_addons WHERE code = 'PREMIUM_SUPPORT');

-- ---- TRAINING -------------------------------------------------------
--
-- The four training charging models are catalogued as billable SKUs here; the
-- contractual scope that must accompany them (subjects, batches, class sizes,
-- sessions, preparation time, assessments, faculty hours and the replacement
-- policy) lives on org_training_agreements in V38.
--
-- TRAINING_FACULTY_HOURS increments INCLUDED_TRAINING_HOURS, so on Managed
-- Academy the 20 hours the base fee already covers are consumed before any
-- purchased hour is drawn down. That is what stops the base fee and the hourly
-- rate billing for the same work.
INSERT INTO plan_addons (code, name, description, category, pricing_model, unit_label,
    unit_price_min, unit_price_max, default_unit_price, min_qty,
    increments_limit_key, hsn_sac_code, fulfilment_notes, display_order)
SELECT 'TRAINING_FACULTY_HOURS', 'Additional training / faculty hours',
    'Trainer-delivered hours beyond those included in your plan.',
    'TRAINING', 'PER_UNIT_ONCE', 'training hour',
    1500.00, 4000.00, 2500.00, 1,
    'INCLUDED_TRAINING_HOURS', '999293',
    'Draws down only after the plan''s included_training_hours are used. Never describe these hours as unlimited. Billable hours must be evidenced by worklog entries.', 50
WHERE NOT EXISTS (SELECT 1 FROM plan_addons WHERE code = 'TRAINING_FACULTY_HOURS');

INSERT INTO plan_addons (code, name, description, category, pricing_model, unit_label,
    unit_price_min, unit_price_max, default_unit_price, min_qty,
    hsn_sac_code, display_order)
SELECT 'TRAINING_PER_STUDENT_PROGRAM', 'Training per student, per program',
    'Trainer-delivered program billed per enrolled student.',
    'TRAINING', 'PER_UNIT_ONCE', 'student per program',
    1500.00, 4000.00, 2500.00, 1,
    '999293', 51
WHERE NOT EXISTS (SELECT 1 FROM plan_addons WHERE code = 'TRAINING_PER_STUDENT_PROGRAM');

INSERT INTO plan_addons (code, name, description, category, pricing_model, unit_label,
    unit_price_min, unit_price_max, default_unit_price, min_qty,
    hsn_sac_code, fulfilment_notes, display_order)
SELECT 'TRAINING_RETAINER', 'Monthly training retainer',
    'A monthly retainer covering an agreed number of trainer hours.',
    'TRAINING', 'FLAT_MONTH', 'month',
    75000.00, 200000.00, 100000.00, 1,
    '999293',
    'The agreement must state the included hours; hours beyond the retainer bill at the TRAINING_FACULTY_HOURS rate. A retainer without a stated hour count is unbillable and undefendable.', 52
WHERE NOT EXISTS (SELECT 1 FROM plan_addons WHERE code = 'TRAINING_RETAINER');

-- Revenue share is deliberately QUOTED and requires_quote. It cannot be computed
-- from platform data unless the academy's fee collection actually runs through
-- the platform — and payment collection is "basic" on Platform with no gateway
-- integrated at all, so today there is nothing to measure a share against.
INSERT INTO plan_addons (code, name, description, category, pricing_model, unit_label,
    unit_price_min, unit_price_max, default_unit_price, min_qty, requires_quote,
    hsn_sac_code, fulfilment_notes, display_order)
SELECT 'TRAINING_REVENUE_SHARE', 'Training revenue share',
    'We supply the platform, content and trainers, and take an agreed share of program revenue.',
    'TRAINING', 'QUOTED', '% of program revenue',
    15.00, 30.00, 20.00, 1, TRUE,
    '999293',
    'Only offer when fee collection runs through the platform, otherwise the share cannot be verified. The agreement must define the revenue base precisely (gross fees collected, net of taxes and refunds) and set a minimum guarantee so trainers are not funded for a program that fails to enrol.', 53
WHERE NOT EXISTS (SELECT 1 FROM plan_addons WHERE code = 'TRAINING_REVENUE_SHARE');
