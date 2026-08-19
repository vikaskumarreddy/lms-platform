-- =====================================================================
-- V35: Give each tenant a real subscription record.
--
-- THE PROBLEM THIS FIXES
-- Until now a tenant's subscription was three denormalised columns on the
-- organizations row: org_subscription_id, purchase_date, expiry_date. That
-- model cannot express plan change history, proration, a trial converting to
-- paid, which add-ons were bought, or what price was actually agreed. Worse,
-- because the organization points at a LIVE plan row, editing a plan's price or
-- limits in the catalog silently repriced and re-limited every tenant already
-- on it — so grandfathering was impossible.
--
-- THE FIX
-- org_subscription_instances holds one row per subscription term, and freezes
-- the price, limits and entitlements as they stood when the term was agreed.
-- Enforcement reads the frozen snapshot, never the catalog, so the catalog
-- becomes a template for NEW business only.
--
-- The organizations.* columns are kept and maintained as a denormalised cache
-- so existing readers (SaasStatsController's revenue and expiry figures, the
-- organizations list, OrganizationService.computeExpiry) continue to work
-- without modification.
--
-- Like the catalog tables, none of these are tenant-scoped: they carry a plain
-- organization_id with no @TenantId, so the platform super admin (whose
-- Hibernate session runs under a sentinel tenant matching no row) can read and
-- aggregate across organizations through JPA.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) Organization billing and contact details.
--
-- These are captured when the organization is created and are what the tenant's
-- Account page echoes back. The GST fields are required to raise a compliant
-- invoice: place_of_supply decides whether tax splits into CGST+SGST (intra
-- state) or is charged as IGST (inter state), so it cannot be an afterthought.
-- ---------------------------------------------------------------------
ALTER TABLE organizations ADD COLUMN IF NOT EXISTS legal_name       VARCHAR(255);
ALTER TABLE organizations ADD COLUMN IF NOT EXISTS gstin            VARCHAR(15);
ALTER TABLE organizations ADD COLUMN IF NOT EXISTS pan              VARCHAR(10);
ALTER TABLE organizations ADD COLUMN IF NOT EXISTS billing_email    VARCHAR(255);
ALTER TABLE organizations ADD COLUMN IF NOT EXISTS billing_phone    VARCHAR(30);
ALTER TABLE organizations ADD COLUMN IF NOT EXISTS billing_address  TEXT;
ALTER TABLE organizations ADD COLUMN IF NOT EXISTS city             VARCHAR(120);
-- Two-digit GST state code, e.g. '36' for Telangana, '29' for Karnataka.
ALTER TABLE organizations ADD COLUMN IF NOT EXISTS state_code       VARCHAR(2);
ALTER TABLE organizations ADD COLUMN IF NOT EXISTS place_of_supply  VARCHAR(120);
ALTER TABLE organizations ADD COLUMN IF NOT EXISTS pincode          VARCHAR(10);
ALTER TABLE organizations ADD COLUMN IF NOT EXISTS country          VARCHAR(80) DEFAULT 'India';
ALTER TABLE organizations ADD COLUMN IF NOT EXISTS contact_person   VARCHAR(160);
-- Sales metadata, surfaced on the Account page so the tenant can see who owns
-- their relationship and which PO their invoices should quote.
ALTER TABLE organizations ADD COLUMN IF NOT EXISTS po_number        VARCHAR(80);
ALTER TABLE organizations ADD COLUMN IF NOT EXISTS sales_owner      VARCHAR(160);
ALTER TABLE organizations ADD COLUMN IF NOT EXISTS notes            TEXT;

-- ---------------------------------------------------------------------
-- 2) Subscription instances
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS org_subscription_instances (
    id                      SERIAL PRIMARY KEY,
    organization_id         BIGINT      NOT NULL,

    plan_id                 BIGINT      NOT NULL,
    -- Denormalised so history stays readable even if the plan is renamed or retired.
    plan_code               VARCHAR(40) NOT NULL,
    plan_name               VARCHAR(255),

    -- TRIALING | PILOT | ACTIVE | PAST_DUE | GRACE | READ_ONLY
    -- | EXPIRED | SUSPENDED | CANCELLED
    status                  VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    -- MONTHLY | YEARLY | CUSTOM | ONE_TIME
    billing_cycle           VARCHAR(10) NOT NULL DEFAULT 'MONTHLY',

    -- The agreed price for one billing period, FROZEN at purchase/renewal. This is
    -- what makes plan grandfathering work: a later catalog price change cannot
    -- reach an existing term.
    unit_price              NUMERIC(12,2),
    currency                CHAR(3)     NOT NULL DEFAULT 'INR',
    -- Tax treatment is frozen too, so a reissued invoice reproduces the original.
    tax_inclusive           BOOLEAN     NOT NULL DEFAULT FALSE,
    gst_rate_pct            NUMERIC(5,2) NOT NULL DEFAULT 18.00,
    hsn_sac_code            VARCHAR(10),

    -- Frozen copies of the plan's limits and entitlements. THESE are what
    -- enforcement reads. Keys match LimitKey / Entitlement constant names.
    limits_snapshot         TEXT        NOT NULL DEFAULT '{}',
    entitlements_snapshot   TEXT        NOT NULL DEFAULT '{}',

    -- Per-tenant negotiated overrides, for the plans whose limits are declared
    -- configurable (Managed Academy, Enterprise). Applied over the snapshot;
    -- purchased add-ons are then added on top, so a negotiated 1,500-student
    -- limit plus 100 bought seats resolves to 1,600.
    limits_override         TEXT,
    entitlements_override   TEXT,

    period_start            TIMESTAMP   NOT NULL DEFAULT NOW(),
    period_end              TIMESTAMP,
    trial_ends_at           TIMESTAMP,
    -- End of the read-only window after expiry, before suspension.
    grace_ends_at           TIMESTAMP,
    -- Set when a cancellation is scheduled for the end of the paid term rather
    -- than taking effect immediately.
    cancel_at               TIMESTAMP,
    cancelled_at            TIMESTAMP,
    activated_at            TIMESTAMP,
    expired_at              TIMESTAMP,
    suspended_at            TIMESTAMP,
    suspension_reason       TEXT,

    auto_renew              BOOLEAN     NOT NULL DEFAULT TRUE,

    -- Chain of terms, so an upgrade path is auditable end to end.
    previous_instance_id    BIGINT,
    -- NEW | UPGRADE | DOWNGRADE | RENEWAL | REACTIVATION | PILOT_CONVERSION
    -- | PLAN_MIGRATION | ADMIN_ADJUSTMENT
    change_reason           VARCHAR(30) NOT NULL DEFAULT 'NEW',
    change_note             TEXT,

    -- Commercial context for sales-assisted deals.
    po_number               VARCHAR(80),
    quotation_ref           VARCHAR(80),
    sales_owner             VARCHAR(160),
    coupon_code             VARCHAR(60),
    discount_amount         NUMERIC(12,2) NOT NULL DEFAULT 0,
    notes                   TEXT,

    -- Exactly one current instance per organization, enforced by a partial
    -- unique index below rather than by application discipline alone.
    is_current              BOOLEAN     NOT NULL DEFAULT TRUE,

    created_at              TIMESTAMP   NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMP   NOT NULL DEFAULT NOW(),
    created_by              VARCHAR(255),

    CONSTRAINT fk_osi_organization FOREIGN KEY (organization_id)
        REFERENCES organizations (id) ON DELETE CASCADE,
    CONSTRAINT fk_osi_plan FOREIGN KEY (plan_id)
        REFERENCES org_subscriptions (id),
    CONSTRAINT fk_osi_previous FOREIGN KEY (previous_instance_id)
        REFERENCES org_subscription_instances (id) ON DELETE SET NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS uk_osi_current_per_org
    ON org_subscription_instances (organization_id) WHERE is_current;
CREATE INDEX IF NOT EXISTS idx_osi_org       ON org_subscription_instances (organization_id, is_current);
CREATE INDEX IF NOT EXISTS idx_osi_status    ON org_subscription_instances (status);
-- Drives the scheduled expiry / grace / dunning sweeps.
CREATE INDEX IF NOT EXISTS idx_osi_period_end ON org_subscription_instances (period_end)
    WHERE is_current;

-- ---------------------------------------------------------------------
-- 3) Purchased add-ons.
--
-- The catalog columns are copied onto each purchase (code, name, unit price,
-- pricing model, and the limit/entitlement keys it grants). That freezing is
-- deliberate: if the catalog definition is later edited to raise a different
-- limit, an existing customer must keep receiving what they actually bought.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS org_subscription_addons (
    id                       SERIAL PRIMARY KEY,
    organization_id          BIGINT      NOT NULL,
    subscription_instance_id BIGINT,

    addon_id                 BIGINT,
    addon_code               VARCHAR(60) NOT NULL,
    addon_name               VARCHAR(160),

    qty                      INT         NOT NULL DEFAULT 1,
    unit_price               NUMERIC(12,2),
    unit_label               VARCHAR(60),
    pricing_model            VARCHAR(20) NOT NULL DEFAULT 'FLAT_ONCE',

    -- Frozen enforcement hooks, as above.
    increments_limit_key     VARCHAR(60),
    grants_entitlement_key   VARCHAR(60),

    -- MONTHLY | YEARLY | ONE_TIME
    billing_period           VARCHAR(10) NOT NULL DEFAULT 'MONTHLY',
    -- ACTIVE | CANCELLED | PENDING_APPROVAL | PENDING_QUOTE
    -- Requests raised from the tenant Account page start PENDING_APPROVAL (or
    -- PENDING_QUOTE for quoted items) and grant nothing until approved.
    status                   VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',

    effective_from           TIMESTAMP   NOT NULL DEFAULT NOW(),
    effective_to             TIMESTAMP,

    hsn_sac_code             VARCHAR(10),
    gst_rate_pct             NUMERIC(5,2) NOT NULL DEFAULT 18.00,

    requested_by             VARCHAR(255),
    approved_by              VARCHAR(255),
    approved_at              TIMESTAMP,
    notes                    TEXT,

    created_at               TIMESTAMP   NOT NULL DEFAULT NOW(),
    updated_at               TIMESTAMP   NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_osa_organization FOREIGN KEY (organization_id)
        REFERENCES organizations (id) ON DELETE CASCADE,
    CONSTRAINT fk_osa_instance FOREIGN KEY (subscription_instance_id)
        REFERENCES org_subscription_instances (id) ON DELETE CASCADE,
    CONSTRAINT ck_osa_qty CHECK (qty > 0)
);

CREATE INDEX IF NOT EXISTS idx_osa_org      ON org_subscription_addons (organization_id, status);
CREATE INDEX IF NOT EXISTS idx_osa_instance ON org_subscription_addons (subscription_instance_id, status);
CREATE INDEX IF NOT EXISTS idx_osa_limit    ON org_subscription_addons (increments_limit_key, status);

-- ---------------------------------------------------------------------
-- 4) Plan change requests.
--
-- The Account page's Upgrade button writes here rather than switching the plan
-- outright. With no live payment gateway, an instant self-serve upgrade would
-- grant entitlements against money that has not been collected. When a plan has
-- self_serve_upgrade_enabled set, the lifecycle service may approve
-- automatically; otherwise the platform team decides.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS org_plan_change_requests (
    id                       SERIAL PRIMARY KEY,
    organization_id          BIGINT      NOT NULL,
    current_instance_id      BIGINT,

    requested_plan_id        BIGINT      NOT NULL,
    requested_plan_code      VARCHAR(40) NOT NULL,
    requested_billing_cycle  VARCHAR(10) NOT NULL DEFAULT 'MONTHLY',
    -- UPGRADE | DOWNGRADE | CYCLE_CHANGE
    request_kind             VARCHAR(20) NOT NULL DEFAULT 'UPGRADE',

    -- PENDING | APPROVED | REJECTED | CANCELLED
    status                   VARCHAR(20) NOT NULL DEFAULT 'PENDING',

    requested_by_user_id     BIGINT,
    requested_by_email       VARCHAR(255),
    requested_note           TEXT,

    decided_by               VARCHAR(255),
    decided_at               TIMESTAMP,
    decision_note            TEXT,
    resulting_instance_id    BIGINT,

    created_at               TIMESTAMP   NOT NULL DEFAULT NOW(),
    updated_at               TIMESTAMP   NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_opcr_organization FOREIGN KEY (organization_id)
        REFERENCES organizations (id) ON DELETE CASCADE,
    CONSTRAINT fk_opcr_plan FOREIGN KEY (requested_plan_id)
        REFERENCES org_subscriptions (id)
);

CREATE INDEX IF NOT EXISTS idx_opcr_org    ON org_plan_change_requests (organization_id, status);
CREATE INDEX IF NOT EXISTS idx_opcr_status ON org_plan_change_requests (status, created_at);
-- At most one open request per organization, so repeated clicks on Upgrade do not
-- queue duplicates for the platform team to reconcile.
CREATE UNIQUE INDEX IF NOT EXISTS uk_opcr_one_pending_per_org
    ON org_plan_change_requests (organization_id) WHERE status = 'PENDING';

-- ---------------------------------------------------------------------
-- 5) Billing event audit trail.
--
-- Every status transition and commercial action is appended here. Billing
-- disputes are argued from this table, so it is append-only by convention: no
-- updates, no deletes.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS org_billing_events (
    id                       SERIAL PRIMARY KEY,
    organization_id          BIGINT      NOT NULL,
    subscription_instance_id BIGINT,

    -- SUBSCRIBED | UPGRADED | DOWNGRADED | RENEWED | CANCELLED | REACTIVATED
    -- | EXPIRED | GRACE_STARTED | READ_ONLY | SUSPENDED | RESUMED
    -- | ADDON_ADDED | ADDON_REMOVED | LIMITS_OVERRIDDEN | INVOICE_ISSUED
    -- | PAYMENT_RECORDED | DUNNING_SENT | PILOT_STARTED | PILOT_CONVERTED
    event_type               VARCHAR(40) NOT NULL,
    from_status              VARCHAR(20),
    to_status                VARCHAR(20),

    actor                    VARCHAR(255),
    summary                  VARCHAR(500),
    detail                   TEXT,

    created_at               TIMESTAMP   NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_obe_organization FOREIGN KEY (organization_id)
        REFERENCES organizations (id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_obe_org  ON org_billing_events (organization_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_obe_type ON org_billing_events (event_type, created_at DESC);

-- ---------------------------------------------------------------------
-- 6) Backfill: give every organization that already has a plan a current
--    subscription instance, so enforcement has something to read from day one
--    rather than treating existing tenants as unsubscribed.
--
--    The snapshot is taken from the plan as it stands right now, which is the
--    best available approximation of what these tenants were sold — the old
--    model recorded no agreed price or limits at all.
-- ---------------------------------------------------------------------
INSERT INTO org_subscription_instances (
    organization_id, plan_id, plan_code, plan_name,
    status, billing_cycle,
    unit_price, currency, tax_inclusive, gst_rate_pct, hsn_sac_code,
    limits_snapshot, entitlements_snapshot,
    period_start, period_end, grace_ends_at,
    auto_renew, change_reason, change_note, is_current,
    activated_at, created_by
)
SELECT
    o.id,
    p.id,
    p.code,
    p.name,
    CASE WHEN o.expiry_date IS NOT NULL AND o.expiry_date < NOW() THEN 'EXPIRED' ELSE 'ACTIVE' END,
    CASE WHEN LOWER(COALESCE(p.period, 'monthly')) = 'yearly' THEN 'YEARLY'
         WHEN LOWER(COALESCE(p.period, 'monthly')) = 'custom' THEN 'CUSTOM'
         ELSE 'MONTHLY' END,
    CASE WHEN LOWER(COALESCE(p.period, 'monthly')) = 'yearly'
         THEN COALESCE(p.price_yearly, p.price_monthly, p.price)
         ELSE COALESCE(p.price_monthly, p.price) END,
    COALESCE(p.currency, 'INR'),
    COALESCE(p.tax_inclusive, FALSE),
    COALESCE(p.gst_rate_pct, 18.00),
    p.hsn_sac_code,
    -- Build the snapshot from the plan's current limits. NULL limits are omitted
    -- entirely, which the resolver reads as unlimited.
    COALESCE((
        SELECT jsonb_strip_nulls(jsonb_build_object(
            'MAX_ACTIVE_STUDENTS',     p.max_active_students,
            'MAX_FACULTY_ACCOUNTS',    p.max_faculty_accounts,
            'MAX_BRANCHES',            p.max_branches,
            'MAX_ORGANIZATIONS',       p.max_organizations,
            'STORAGE_GB',              p.storage_gb,
            'INCLUDED_TRAINING_HOURS', p.included_training_hours
        ))::text
    ), '{}'),
    COALESCE(p.entitlements, '{}'),
    COALESCE(o.purchase_date, o.created_at, NOW()),
    o.expiry_date,
    o.expiry_date + (COALESCE(p.grace_days, 15) || ' days')::interval,
    TRUE,
    'PLAN_MIGRATION',
    'Backfilled by V35 from the organization''s existing plan assignment. The previous data model recorded no agreed price or limits, so the snapshot reflects the plan as it stood at migration time.',
    TRUE,
    COALESCE(o.purchase_date, o.created_at, NOW()),
    'system:V35'
FROM organizations o
JOIN org_subscriptions p ON p.id = o.org_subscription_id
WHERE o.org_subscription_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM org_subscription_instances i
      WHERE i.organization_id = o.id AND i.is_current
  );

-- Record the backfill so the audit trail does not begin with an unexplained state.
INSERT INTO org_billing_events (organization_id, subscription_instance_id, event_type,
                                to_status, actor, summary, created_at)
SELECT i.organization_id, i.id, 'SUBSCRIBED', i.status, 'system:V35',
       'Subscription instance backfilled from the legacy plan assignment on ' || i.plan_code,
       NOW()
FROM org_subscription_instances i
WHERE i.created_by = 'system:V35'
  AND NOT EXISTS (
      SELECT 1 FROM org_billing_events e
      WHERE e.subscription_instance_id = i.id AND e.actor = 'system:V35'
  );
