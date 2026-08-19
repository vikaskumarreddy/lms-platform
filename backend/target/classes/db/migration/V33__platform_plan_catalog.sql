-- =====================================================================
-- V33: Turn org_subscriptions from a marketing list into an enforceable
--      product catalog.
--
-- Before this migration a "plan" carried only name/price/period plus a JSON
-- array of feature *strings*. It had no limits at all — the seeded rows
-- literally advertised "Unlimited students" — and nothing in the application
-- read them. Every tenant was therefore effectively unlimited.
--
-- This adds:
--   * a stable `code` so application logic can reference plans without
--     depending on their display names
--   * separate monthly/annual pricing with the discount recorded
--   * GST fields, because whether 4,999 includes 18% tax is an 18% swing and
--     was previously undefined
--   * countable limits (students, faculty seats, branches, storage, training
--     hours) matching com.institute.lms.subscription.LimitKey
--   * an `entitlements` JSON map matching com.institute.lms.subscription.Entitlement,
--     storing only granted keys (absent == not included)
--   * overage controls, so buying extra seats can be priced ABOVE the next
--     tier's effective rate rather than undercutting it
--
-- The legacy price/period/features/is_popular columns are retained and kept
-- consistent, so existing reads (SaasStatsController, OrganizationService's
-- expiry computation, the current plan list UI) keep working untouched.
--
-- NOTE: org_subscriptions is intentionally NOT a tenant-scoped table. It has
-- no organization_id and does not extend BaseEntity, so the platform super
-- admin (who runs under a sentinel tenant that matches no row) can still read
-- it through JPA. V31 made subscription_plans tenant-scoped and needed a
-- backfill to undo the consequences; do not repeat that here.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) Identity, ordering and visibility
-- ---------------------------------------------------------------------
ALTER TABLE org_subscriptions ADD COLUMN IF NOT EXISTS code            VARCHAR(40);
ALTER TABLE org_subscriptions ADD COLUMN IF NOT EXISTS tier_rank       INT     NOT NULL DEFAULT 0;
ALTER TABLE org_subscriptions ADD COLUMN IF NOT EXISTS display_order   INT     NOT NULL DEFAULT 0;
-- is_public = show as a self-serve card on the tenant Account page. The pilot
-- plan is deliberately not public: it is sold, not chosen.
ALTER TABLE org_subscriptions ADD COLUMN IF NOT EXISTS is_public       BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE org_subscriptions ADD COLUMN IF NOT EXISTS tagline         VARCHAR(255);

-- ---------------------------------------------------------------------
-- 2) Pricing
-- ---------------------------------------------------------------------
ALTER TABLE org_subscriptions ADD COLUMN IF NOT EXISTS price_monthly   NUMERIC(12,2);
ALTER TABLE org_subscriptions ADD COLUMN IF NOT EXISTS price_yearly    NUMERIC(12,2);
-- Recorded rather than derived so the commercial intent survives price edits,
-- and so the plan editor can flag a plan that drifts outside the 15-20% band.
ALTER TABLE org_subscriptions ADD COLUMN IF NOT EXISTS annual_discount_pct NUMERIC(5,2);
ALTER TABLE org_subscriptions ADD COLUMN IF NOT EXISTS currency        CHAR(3) NOT NULL DEFAULT 'INR';
-- Enterprise: no list price, sales quotes each deal.
ALTER TABLE org_subscriptions ADD COLUMN IF NOT EXISTS is_custom_priced BOOLEAN NOT NULL DEFAULT FALSE;

-- ---------------------------------------------------------------------
-- 3) GST / invoicing metadata
--    Prices are stored EXCLUSIVE of tax; the UI renders "+18% GST".
--    SAC 997331 = licensing services for the right to use software (the
--    subscription itself). Training services carry a different SAC (999293),
--    which is why the code lives per-plan and per-add-on rather than globally.
-- ---------------------------------------------------------------------
ALTER TABLE org_subscriptions ADD COLUMN IF NOT EXISTS tax_inclusive   BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE org_subscriptions ADD COLUMN IF NOT EXISTS hsn_sac_code    VARCHAR(10);
ALTER TABLE org_subscriptions ADD COLUMN IF NOT EXISTS gst_rate_pct    NUMERIC(5,2) NOT NULL DEFAULT 18.00;

-- ---------------------------------------------------------------------
-- 4) Limits. NULL means unlimited (LimitKey.UNLIMITED), which is how
--    Enterprise and negotiated custom limits are expressed.
-- ---------------------------------------------------------------------
ALTER TABLE org_subscriptions ADD COLUMN IF NOT EXISTS max_active_students     INT;
ALTER TABLE org_subscriptions ADD COLUMN IF NOT EXISTS max_faculty_accounts    INT;
ALTER TABLE org_subscriptions ADD COLUMN IF NOT EXISTS max_branches            INT;
ALTER TABLE org_subscriptions ADD COLUMN IF NOT EXISTS max_organizations       INT;
ALTER TABLE org_subscriptions ADD COLUMN IF NOT EXISTS storage_gb              INT;
-- Managed Academy bundles training hours AND the contract meters extra hours.
-- Without an explicit included figure, every deal becomes an argument about
-- what the base fee already covered.
ALTER TABLE org_subscriptions ADD COLUMN IF NOT EXISTS included_training_hours NUMERIC(6,2) NOT NULL DEFAULT 0;
-- Managed/Enterprise agreements may override limits per tenant.
ALTER TABLE org_subscriptions ADD COLUMN IF NOT EXISTS limits_configurable     BOOLEAN NOT NULL DEFAULT FALSE;

-- ---------------------------------------------------------------------
-- 5) Overage controls.
--
--    These exist to stop the extra-student add-on cannibalising the tier above
--    it. At a flat 15/student, an academy with 500 students pays
--    4,999 + 300*15 = 9,499 on Platform versus 12,999 on Platform Plus, so
--    capacity would never drive an upgrade. Two levers fix it:
--      * overage_student_price is set per plan ABOVE the next tier's effective
--        per-student rate (Platform 25/student -> overage 40)
--      * overage_students_allowed caps how many seats can be stacked before an
--        upgrade is required (25% of the plan allowance)
--    Both are columns so pricing can be retuned without a deploy.
-- ---------------------------------------------------------------------
ALTER TABLE org_subscriptions ADD COLUMN IF NOT EXISTS overage_students_allowed INT NOT NULL DEFAULT 0;
ALTER TABLE org_subscriptions ADD COLUMN IF NOT EXISTS overage_student_price    NUMERIC(8,2);

-- ---------------------------------------------------------------------
-- 6) Entitlements + lifecycle flags
--     entitlements: JSON object of Entitlement name -> true | number.
--     Only granted keys are present; absent means not included. This keeps the
--     seed data readable and means adding a new Entitlement constant does not
--     require rewriting every plan row.
-- ---------------------------------------------------------------------
ALTER TABLE org_subscriptions ADD COLUMN IF NOT EXISTS entitlements    TEXT NOT NULL DEFAULT '{}';
ALTER TABLE org_subscriptions ADD COLUMN IF NOT EXISTS trial_days      INT  NOT NULL DEFAULT 0;
ALTER TABLE org_subscriptions ADD COLUMN IF NOT EXISTS grace_days      INT  NOT NULL DEFAULT 15;
-- Default FALSE: with no live payment gateway, letting a tenant upgrade
-- themselves would grant entitlements against uncollected money. The Upgrade
-- button therefore raises a request for the platform team to approve.
ALTER TABLE org_subscriptions ADD COLUMN IF NOT EXISTS self_serve_upgrade_enabled BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE org_subscriptions ADD COLUMN IF NOT EXISTS requires_quote  BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE org_subscriptions ADD COLUMN IF NOT EXISTS fulfilment_notes TEXT;

-- ---------------------------------------------------------------------
-- 7) Adopt the three pre-existing seed rows by name so any organization
--    already pointing at them keeps a valid plan reference. Their old prices
--    (0 / 990 / 2490) were placeholders and are replaced below.
-- ---------------------------------------------------------------------
UPDATE org_subscriptions SET code = 'PLATFORM'       WHERE code IS NULL AND name = 'Platform Only';
UPDATE org_subscriptions SET code = 'PLATFORM_PLUS'  WHERE code IS NULL AND name = 'Platform + Training Support';
UPDATE org_subscriptions SET code = 'ENTERPRISE'     WHERE code IS NULL AND name = 'Enterprise';

-- Any other legacy row keeps working but is retired from the catalog: it gets a
-- generated code and is hidden, rather than deleted, because organizations may
-- still reference it and their frozen snapshot must stay resolvable.
UPDATE org_subscriptions
SET code      = 'LEGACY_' || id,
    is_public = FALSE,
    is_active = FALSE
WHERE code IS NULL;

-- ---------------------------------------------------------------------
-- 8) Create any of the five catalog plans that does not exist yet.
--    Only identity is inserted here; step 9 sets every attribute for both
--    newly-inserted and adopted rows, so the end state is identical either way
--    and the migration is idempotent.
-- ---------------------------------------------------------------------
INSERT INTO org_subscriptions (name, code, price, period, features)
SELECT 'Platform', 'PLATFORM', 0, 'monthly', '[]'
WHERE NOT EXISTS (SELECT 1 FROM org_subscriptions WHERE code = 'PLATFORM');

INSERT INTO org_subscriptions (name, code, price, period, features)
SELECT 'Platform Plus', 'PLATFORM_PLUS', 0, 'monthly', '[]'
WHERE NOT EXISTS (SELECT 1 FROM org_subscriptions WHERE code = 'PLATFORM_PLUS');

INSERT INTO org_subscriptions (name, code, price, period, features)
SELECT 'Managed Academy', 'MANAGED_ACADEMY', 0, 'monthly', '[]'
WHERE NOT EXISTS (SELECT 1 FROM org_subscriptions WHERE code = 'MANAGED_ACADEMY');

INSERT INTO org_subscriptions (name, code, price, period, features)
SELECT 'Enterprise', 'ENTERPRISE', 0, 'custom', '[]'
WHERE NOT EXISTS (SELECT 1 FROM org_subscriptions WHERE code = 'ENTERPRISE');

INSERT INTO org_subscriptions (name, code, price, period, features)
SELECT 'Assisted Pilot', 'PILOT', 0, 'custom', '[]'
WHERE NOT EXISTS (SELECT 1 FROM org_subscriptions WHERE code = 'PILOT');

-- ---------------------------------------------------------------------
-- 9) Populate the catalog.
-- ---------------------------------------------------------------------

-- PLATFORM — 4,999/mo, 49,999/yr.
-- 59,988 - 49,999 = 9,989 saved => 16.65% annual discount.
-- 4,999 / 200 students = 25.00 per student per month, which is why the overage
-- price is set to 40 (above Platform Plus's 26.00 effective rate).
UPDATE org_subscriptions SET
    name = 'Platform',
    tagline = 'Run your academy on our platform',
    description = 'The complete academy platform: courses, classes, assessments, placements and certificates for a single organization.',
    tier_rank = 10, display_order = 1, is_public = TRUE, is_active = TRUE, is_popular = FALSE,
    price_monthly = 4999.00, price_yearly = 49999.00, annual_discount_pct = 16.65,
    currency = 'INR', is_custom_priced = FALSE,
    tax_inclusive = FALSE, hsn_sac_code = '997331', gst_rate_pct = 18.00,
    max_active_students = 200, max_faculty_accounts = 5, max_branches = 1, max_organizations = 1,
    storage_gb = 25, included_training_hours = 0, limits_configurable = FALSE,
    overage_students_allowed = 50, overage_student_price = 40.00,
    trial_days = 0, grace_days = 15, self_serve_upgrade_enabled = FALSE, requires_quote = FALSE,
    entitlements = '{
        "MULTI_TENANT_DASHBOARD": true,
        "STUDENT_MOBILE_APP": true,
        "COURSE_MANAGEMENT": true,
        "NOTES_AND_MATERIALS": true,
        "CLASSES": true,
        "ASSIGNMENTS_AND_EXAMS": true,
        "BASIC_PAYMENT_COLLECTION": true,
        "RESUME_BUILDER": true,
        "CERTIFICATES": true,
        "PLACEMENT_NOTIFICATIONS": true,
        "BASIC_REPORTS": true,
        "STANDARD_SUPPORT": true
    }',
    price = 4999.00, period = 'monthly',
    features = '["Multi-tenant academy dashboard","Shared student mobile application","Course management","Notes and learning materials","Classes","Assignments and examinations","Basic payment collection","Resume builder","Certificates","Placement notifications","Basic reports","Standard support","200 active students","5 faculty seats","1 organization","25 GB storage"]'
WHERE code = 'PLATFORM';

-- PLATFORM_PLUS — 12,999/mo, 1,29,999/yr.
-- 1,55,988 - 1,29,999 = 25,989 saved => 16.66% annual discount (matches Platform).
-- The website/migration inclusions are quantified rather than open-ended so the
-- delivery boundary is checkable; anything beyond routes to the matching add-on.
UPDATE org_subscriptions SET
    name = 'Platform Plus',
    tagline = 'Your own branded academy, with us alongside you',
    description = 'Everything in Platform, plus a branded website on your own domain, advanced placements and analytics, automated communication and priority support.',
    tier_rank = 20, display_order = 2, is_public = TRUE, is_active = TRUE, is_popular = TRUE,
    price_monthly = 12999.00, price_yearly = 129999.00, annual_discount_pct = 16.66,
    currency = 'INR', is_custom_priced = FALSE,
    tax_inclusive = FALSE, hsn_sac_code = '997331', gst_rate_pct = 18.00,
    max_active_students = 500, max_faculty_accounts = 15, max_branches = 5, max_organizations = 1,
    storage_gb = 100, included_training_hours = 0, limits_configurable = FALSE,
    overage_students_allowed = 125, overage_student_price = 30.00,
    trial_days = 0, grace_days = 15, self_serve_upgrade_enabled = FALSE, requires_quote = FALSE,
    entitlements = '{
        "MULTI_TENANT_DASHBOARD": true,
        "STUDENT_MOBILE_APP": true,
        "COURSE_MANAGEMENT": true,
        "NOTES_AND_MATERIALS": true,
        "CLASSES": true,
        "ASSIGNMENTS_AND_EXAMS": true,
        "BASIC_PAYMENT_COLLECTION": true,
        "RESUME_BUILDER": true,
        "CERTIFICATES": true,
        "PLACEMENT_NOTIFICATIONS": true,
        "BASIC_REPORTS": true,
        "BRANDED_WEBSITE": true,
        "CUSTOM_DOMAIN": true,
        "WEBSITE_MAINTENANCE": true,
        "ADDITIONAL_BRANDING": true,
        "PRIORITY_SUPPORT": true,
        "ASSISTED_ONBOARDING": true,
        "DATA_MIGRATION_ASSISTED": true,
        "ADVANCED_PLACEMENT_MANAGEMENT": true,
        "ADVANCED_ANALYTICS": true,
        "AUTOMATED_COMMUNICATION": true,
        "CUSTOMER_SUCCESS_CONTACT": true,
        "MULTI_BRANCH": true,
        "WEBSITE_PAGES_INCLUDED": 8,
        "WEBSITE_REVISIONS_INCLUDED": 3,
        "MAINTENANCE_HOURS_PER_QUARTER": 4,
        "MIGRATION_RECORDS_INCLUDED": 500
    }',
    price = 12999.00, period = 'monthly',
    features = '["Everything in Platform","Branded academy website","Custom domain","Website maintenance (4 hrs/quarter)","Priority support","Assisted onboarding","Data migration (up to 500 records)","Advanced placement management","Advanced analytics and reports","Additional branding options","Automated communication","Dedicated customer success contact","Up to 5 branches","500 active students","15 faculty seats","100 GB storage"]'
WHERE code = 'PLATFORM_PLUS';

-- MANAGED_ACADEMY — 49,999/mo. 5,99,988/yr at list; 4,99,999 annual applies the
-- same ~16.7% discount the other two tiers use, so it is not renegotiated deal
-- by deal.
--
-- included_training_hours = 20: the base fee bundles "allocated training or
-- faculty assistance", and the contract ALSO meters training per hour. Without a
-- stated included figure those two clauses contradict each other. The per-hour
-- rate (see the TRAINING_FACULTY_HOURS add-on) starts only beyond these 20 hours.
-- Note "allocated", never "unlimited".
UPDATE org_subscriptions SET
    name = 'Managed Academy',
    tagline = 'We run the platform, you teach',
    description = 'Everything in Platform Plus, and we operate it for you: platform and website administration, student support, course administration, monthly reporting and allocated operational and training support.',
    tier_rank = 30, display_order = 3, is_public = TRUE, is_active = TRUE, is_popular = FALSE,
    price_monthly = 49999.00, price_yearly = 499999.00, annual_discount_pct = 16.66,
    currency = 'INR', is_custom_priced = FALSE,
    tax_inclusive = FALSE, hsn_sac_code = '997331', gst_rate_pct = 18.00,
    max_active_students = 1000, max_faculty_accounts = 30, max_branches = 10, max_organizations = 1,
    storage_gb = 250, included_training_hours = 20, limits_configurable = TRUE,
    overage_students_allowed = 250, overage_student_price = 20.00,
    trial_days = 0, grace_days = 30, self_serve_upgrade_enabled = FALSE, requires_quote = TRUE,
    fulfilment_notes = 'Annual contract preferred. The agreement must define subjects, batches, class sizes, number of sessions, preparation time, assessments, faculty hours and the faculty replacement policy before go-live.',
    entitlements = '{
        "MULTI_TENANT_DASHBOARD": true,
        "STUDENT_MOBILE_APP": true,
        "COURSE_MANAGEMENT": true,
        "NOTES_AND_MATERIALS": true,
        "CLASSES": true,
        "ASSIGNMENTS_AND_EXAMS": true,
        "BASIC_PAYMENT_COLLECTION": true,
        "RESUME_BUILDER": true,
        "CERTIFICATES": true,
        "PLACEMENT_NOTIFICATIONS": true,
        "BASIC_REPORTS": true,
        "BRANDED_WEBSITE": true,
        "CUSTOM_DOMAIN": true,
        "WEBSITE_MAINTENANCE": true,
        "ADDITIONAL_BRANDING": true,
        "PRIORITY_SUPPORT": true,
        "ASSISTED_ONBOARDING": true,
        "DATA_MIGRATION_ASSISTED": true,
        "ADVANCED_PLACEMENT_MANAGEMENT": true,
        "ADVANCED_ANALYTICS": true,
        "AUTOMATED_COMMUNICATION": true,
        "CUSTOMER_SUCCESS_CONTACT": true,
        "MULTI_BRANCH": true,
        "PLATFORM_ADMINISTRATION": true,
        "STUDENT_SUPPORT_DESK": true,
        "COURSE_ADMINISTRATION": true,
        "MONTHLY_REPORTING": true,
        "OPERATIONAL_SUPPORT_ALLOCATED": true,
        "TRAINING_SUPPORT_ALLOCATED": true,
        "DEDICATED_ACCOUNT_MANAGER": true,
        "DEFINED_SLA": true,
        "WEBSITE_PAGES_INCLUDED": 20,
        "WEBSITE_REVISIONS_INCLUDED": 6,
        "MAINTENANCE_HOURS_PER_QUARTER": 12,
        "MIGRATION_RECORDS_INCLUDED": 2000,
        "OPERATIONAL_SUPPORT_HOURS_PER_MONTH": 40
    }',
    price = 49999.00, period = 'monthly',
    features = '["Everything in Platform Plus","Website and platform administration","Student support","Course administration","Monthly reporting","Allocated operational support (40 hrs/month)","Allocated training and faculty assistance (20 hrs/month)","Dedicated account manager","Defined service-level agreement","1,000 active students (configurable)","30 faculty seats (configurable)","Up to 10 branches","250 GB storage"]'
WHERE code = 'MANAGED_ACADEMY';

-- ENTERPRISE — custom priced, limits negotiated per agreement (NULL = unlimited).
-- SSO, dedicated infrastructure, white-labelled apps and custom integrations are
-- flagged sales-qualified in the Entitlement enum: none can be provisioned by
-- flipping a flag today, so the UI must present them as contracted, not instant.
UPDATE org_subscriptions SET
    name = 'Enterprise',
    tagline = 'Built around your organization',
    description = 'Multiple organizations or branches, custom limits, SSO, APIs and integrations, custom roles and workflows, advanced security and audit logs, white-labelled mobile applications and a defined SLA.',
    tier_rank = 40, display_order = 4, is_public = TRUE, is_active = TRUE, is_popular = FALSE,
    price_monthly = NULL, price_yearly = NULL, annual_discount_pct = NULL,
    currency = 'INR', is_custom_priced = TRUE,
    tax_inclusive = FALSE, hsn_sac_code = '997331', gst_rate_pct = 18.00,
    max_active_students = NULL, max_faculty_accounts = NULL, max_branches = NULL, max_organizations = NULL,
    storage_gb = NULL, included_training_hours = 0, limits_configurable = TRUE,
    overage_students_allowed = 0, overage_student_price = NULL,
    trial_days = 0, grace_days = 30, self_serve_upgrade_enabled = FALSE, requires_quote = TRUE,
    fulfilment_notes = 'Dedicated infrastructure means a separate deployment, not a configuration flag. SSO requires SAML/OIDC work that does not exist in the platform today. White-labelled mobile apps need a per-tenant build and separate Play/App Store listings. Scope and lead time must be agreed with engineering before these are committed to a customer.',
    entitlements = '{
        "MULTI_TENANT_DASHBOARD": true,
        "STUDENT_MOBILE_APP": true,
        "COURSE_MANAGEMENT": true,
        "NOTES_AND_MATERIALS": true,
        "CLASSES": true,
        "ASSIGNMENTS_AND_EXAMS": true,
        "BASIC_PAYMENT_COLLECTION": true,
        "RESUME_BUILDER": true,
        "CERTIFICATES": true,
        "PLACEMENT_NOTIFICATIONS": true,
        "BASIC_REPORTS": true,
        "BRANDED_WEBSITE": true,
        "CUSTOM_DOMAIN": true,
        "WEBSITE_MAINTENANCE": true,
        "ADDITIONAL_BRANDING": true,
        "PRIORITY_SUPPORT": true,
        "ASSISTED_ONBOARDING": true,
        "DATA_MIGRATION_ASSISTED": true,
        "ADVANCED_PLACEMENT_MANAGEMENT": true,
        "ADVANCED_ANALYTICS": true,
        "AUTOMATED_COMMUNICATION": true,
        "CUSTOMER_SUCCESS_CONTACT": true,
        "MULTI_BRANCH": true,
        "PLATFORM_ADMINISTRATION": true,
        "MONTHLY_REPORTING": true,
        "DEDICATED_ACCOUNT_MANAGER": true,
        "DEFINED_SLA": true,
        "MULTI_ORGANIZATION": true,
        "SSO": true,
        "API_ACCESS": true,
        "CUSTOM_ROLES_AND_WORKFLOWS": true,
        "DEDICATED_INFRASTRUCTURE": true,
        "ADVANCED_SECURITY_AUDIT_LOGS": true,
        "DATA_MIGRATION_FULL": true,
        "CUSTOM_REPORTS": true,
        "WHITE_LABEL_MOBILE_APP": true,
        "CUSTOM_INTEGRATIONS": true,
        "USAGE_AND_BILLING_RULES": true
    }',
    price = 0, period = 'custom',
    features = '["Multiple organizations or branches","Custom student and faculty limits","Single sign-on","APIs and integrations","Custom roles and workflows","Dedicated infrastructure where necessary","Advanced security and audit logs","Data migration","Defined SLA","Dedicated account manager","Custom reports","White-labelled mobile applications","Custom usage and billing rules"]'
WHERE code = 'ENTERPRISE';

-- PILOT — the 60-90 day assisted pilot, priced 15,000-30,000 (25,000 default).
--
-- is_public = FALSE: this is sold by the team, not picked from a pricing page.
-- trial_days = 60 rather than 90: at 15-25 person-hours of setup, onboarding,
-- import, configuration and review, the fee is at or below cost, so it only
-- works as customer acquisition if it converts promptly. 90 days is long enough
-- for an academy to run a full batch and leave. 90 remains available by
-- exception via the pilot record's own end date.
UPDATE org_subscriptions SET
    name = 'Assisted Pilot',
    tagline = '60-day assisted pilot',
    description = 'A time-boxed, assisted pilot: organization setup, faculty onboarding, a limited student and course import, platform configuration, defined support and a usage review — with the fee credited in full against your first annual invoice on conversion.',
    tier_rank = 5, display_order = 0, is_public = FALSE, is_active = TRUE, is_popular = FALSE,
    price_monthly = 25000.00, price_yearly = NULL, annual_discount_pct = NULL,
    currency = 'INR', is_custom_priced = FALSE,
    tax_inclusive = FALSE, hsn_sac_code = '997331', gst_rate_pct = 18.00,
    max_active_students = 100, max_faculty_accounts = 5, max_branches = 1, max_organizations = 1,
    storage_gb = 10, included_training_hours = 0, limits_configurable = TRUE,
    overage_students_allowed = 0, overage_student_price = NULL,
    trial_days = 60, grace_days = 7, self_serve_upgrade_enabled = FALSE, requires_quote = TRUE,
    fulfilment_notes = 'Fee is 15,000-30,000 depending on scope and is credited in full against the first annual invoice on conversion; non-refundable otherwise. The pilot agreement must state a decision due date.',
    entitlements = '{
        "MULTI_TENANT_DASHBOARD": true,
        "STUDENT_MOBILE_APP": true,
        "COURSE_MANAGEMENT": true,
        "NOTES_AND_MATERIALS": true,
        "CLASSES": true,
        "ASSIGNMENTS_AND_EXAMS": true,
        "BASIC_PAYMENT_COLLECTION": true,
        "RESUME_BUILDER": true,
        "CERTIFICATES": true,
        "PLACEMENT_NOTIFICATIONS": true,
        "BASIC_REPORTS": true,
        "STANDARD_SUPPORT": true,
        "ASSISTED_ONBOARDING": true,
        "DATA_MIGRATION_ASSISTED": true,
        "MIGRATION_RECORDS_INCLUDED": 100
    }',
    price = 25000.00, period = 'custom',
    features = '["Organization setup","Faculty onboarding","Limited student and course import (up to 100 records)","Platform configuration","Defined support","Usage review","Converts to an annual plan with the fee credited","100 active students","5 faculty seats","10 GB storage"]'
WHERE code = 'PILOT';

-- ---------------------------------------------------------------------
-- 10) Constraints and indexes. The unique index is created last, after every
--     row has been assigned a code.
-- ---------------------------------------------------------------------
ALTER TABLE org_subscriptions ALTER COLUMN code SET NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uk_org_subscriptions_code ON org_subscriptions (code);
CREATE INDEX IF NOT EXISTS idx_org_subscriptions_public
    ON org_subscriptions (is_public, is_active, display_order);

-- Guard the pricing invariants that the application relies on: a plan is either
-- custom-priced or it has a monthly price, never neither.
ALTER TABLE org_subscriptions DROP CONSTRAINT IF EXISTS ck_org_subscriptions_pricing;
ALTER TABLE org_subscriptions ADD CONSTRAINT ck_org_subscriptions_pricing
    CHECK (is_custom_priced = TRUE OR price_monthly IS NOT NULL OR is_active = FALSE);
