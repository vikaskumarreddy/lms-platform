-- =====================================================================
-- V36: Usage metering — the measurement layer that billing depends on.
--
-- WHY AN ACTIVITY LEDGER RATHER THAN A COUNT
-- Active students are the billable metric, so the count has to be defensible
-- when a customer disputes an invoice. The only pre-existing signal was
-- users.last_login, a single overwritten timestamp: it can answer "did this
-- student log in recently" but not "was this student active in July", which is
-- exactly the question an invoice for July has to answer. Once overwritten, the
-- evidence is gone for good.
--
-- student_activity_period is therefore append-only, one row per
-- (organization, student, billing month), created on the student's first
-- qualifying event that month and enriched thereafter. That yields:
--   * an auditable count per month, reconstructable years later
--   * inactive and alumni students costing nothing automatically, because no row
--     is written for a month in which they did nothing
--   * a record of WHICH activity qualified them, so "why is this student
--     billable" has an answer
--
-- Qualifying events, per the commercial definition: logging in, accessing
-- content, attending a class, submitting an assessment, or applying to a
-- placement drive.
--
-- Not tenant-scoped: a plain organization_id with no @TenantId, so the platform
-- can aggregate across tenants for billing.
-- =====================================================================

CREATE TABLE IF NOT EXISTS student_activity_period (
    id                  SERIAL PRIMARY KEY,
    organization_id     BIGINT      NOT NULL,
    student_id          BIGINT      NOT NULL,

    -- Billing month as 'YYYY-MM'. A char key rather than a date because it is a
    -- billing bucket, not a point in time, and it makes the uniqueness constraint
    -- and every aggregation read plainly.
    period_ym           CHAR(7)     NOT NULL,

    first_activity_at   TIMESTAMP   NOT NULL DEFAULT NOW(),
    last_activity_at    TIMESTAMP   NOT NULL DEFAULT NOW(),
    activity_count      INT         NOT NULL DEFAULT 1,

    -- Which event first made this student billable this month, and the set of all
    -- event types seen since. LOGIN | CONTENT_ACCESS | CLASS_ATTENDANCE
    -- | ASSESSMENT_SUBMISSION | PLACEMENT_APPLICATION
    first_activity_type VARCHAR(30) NOT NULL,
    activity_types      TEXT        NOT NULL DEFAULT '[]',

    -- TRUE when this student was over the plan allowance in this month. Set by the
    -- meter rather than computed later, because the allowance in force at the time
    -- is what matters and it may since have changed.
    was_overage         BOOLEAN     NOT NULL DEFAULT FALSE,

    created_at          TIMESTAMP   NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMP   NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_sap_organization FOREIGN KEY (organization_id)
        REFERENCES organizations (id) ON DELETE CASCADE
);

-- The uniqueness rule that makes the meter idempotent: a student's tenth login in
-- a month must increment a counter, never create a second billable row.
CREATE UNIQUE INDEX IF NOT EXISTS uk_sap_org_student_period
    ON student_activity_period (organization_id, student_id, period_ym);
-- The hot path: counting a tenant's active students for the current month.
CREATE INDEX IF NOT EXISTS idx_sap_org_period
    ON student_activity_period (organization_id, period_ym);
CREATE INDEX IF NOT EXISTS idx_sap_student
    ON student_activity_period (student_id, period_ym);

-- =====================================================================
-- Monthly usage rollup — what invoices and overage add-ons actually bill from.
--
-- Kept separate from the ledger because an invoice needs a single agreed figure,
-- frozen at the close of the period. Recomputing from the ledger at invoice time
-- would let a late-arriving activity row change a figure that has already been
-- billed.
--
-- Both a peak and an end-of-period count are captured: peak is the honest basis
-- for a metric sold as "active students", since a tenant who runs 400 students
-- for three weeks and 150 on the last day did not use a 150-student plan.
-- =====================================================================
CREATE TABLE IF NOT EXISTS org_usage_snapshot (
    id                       SERIAL PRIMARY KEY,
    organization_id          BIGINT      NOT NULL,
    period_ym                CHAR(7)     NOT NULL,
    captured_at              TIMESTAMP   NOT NULL DEFAULT NOW(),
    -- TRUE once the period has closed and the figures are final.
    is_final                 BOOLEAN     NOT NULL DEFAULT FALSE,

    active_students_peak     INT         NOT NULL DEFAULT 0,
    active_students_end      INT         NOT NULL DEFAULT 0,
    faculty_accounts         INT         NOT NULL DEFAULT 0,
    branches                 INT         NOT NULL DEFAULT 0,
    storage_bytes            BIGINT      NOT NULL DEFAULT 0,

    -- Communication credits consumed in the period.
    sms_used                 INT         NOT NULL DEFAULT 0,
    whatsapp_used            INT         NOT NULL DEFAULT 0,
    email_used               INT         NOT NULL DEFAULT 0,
    -- Trainer hours delivered, against the plan's included allowance.
    training_hours_used      NUMERIC(8,2) NOT NULL DEFAULT 0,

    -- The allowance in force during the period, copied so the overage figure can be
    -- explained afterwards even if the tenant has since changed plan.
    students_allowance       INT,
    overage_students         INT         NOT NULL DEFAULT 0,
    overage_student_price    NUMERIC(8,2),
    overage_amount           NUMERIC(12,2) NOT NULL DEFAULT 0,

    plan_code                VARCHAR(40),
    -- Any additional measured detail, as JSON.
    snapshot_json            TEXT,

    created_at               TIMESTAMP   NOT NULL DEFAULT NOW(),
    updated_at               TIMESTAMP   NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_ous_organization FOREIGN KEY (organization_id)
        REFERENCES organizations (id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS uk_ous_org_period
    ON org_usage_snapshot (organization_id, period_ym);
CREATE INDEX IF NOT EXISTS idx_ous_period ON org_usage_snapshot (period_ym, is_final);

-- =====================================================================
-- Prepaid communication credits.
--
-- A running balance plus an immutable transaction ledger, rather than a bare
-- counter. "You said we had 5,000 SMS credits" is only answerable with the
-- ledger, and a balance that can be recomputed from transactions can be audited
-- when it disagrees with the customer's own count.
-- =====================================================================
CREATE TABLE IF NOT EXISTS org_credit_balance (
    organization_id  BIGINT      NOT NULL,
    -- SMS | WHATSAPP | EMAIL
    credit_type      VARCHAR(20) NOT NULL,
    balance          BIGINT      NOT NULL DEFAULT 0,
    lifetime_granted BIGINT      NOT NULL DEFAULT 0,
    lifetime_used    BIGINT      NOT NULL DEFAULT 0,
    updated_at       TIMESTAMP   NOT NULL DEFAULT NOW(),

    PRIMARY KEY (organization_id, credit_type),
    CONSTRAINT fk_ocb_organization FOREIGN KEY (organization_id)
        REFERENCES organizations (id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS org_credit_txn (
    id               SERIAL PRIMARY KEY,
    organization_id  BIGINT      NOT NULL,
    credit_type      VARCHAR(20) NOT NULL,
    -- PURCHASE | CONSUMPTION | ADJUSTMENT | EXPIRY | REFUND
    txn_type         VARCHAR(20) NOT NULL,
    -- Positive to grant, negative to consume.
    amount           BIGINT      NOT NULL,
    balance_after    BIGINT      NOT NULL,

    reference        VARCHAR(160),
    addon_code       VARCHAR(60),
    actor            VARCHAR(255),
    notes            TEXT,
    created_at       TIMESTAMP   NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_oct_organization FOREIGN KEY (organization_id)
        REFERENCES organizations (id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_oct_org ON org_credit_txn (organization_id, credit_type, created_at DESC);

-- =====================================================================
-- Storage accounting.
--
-- A counter maintained on upload and delete, which is enough to enforce the plan
-- allowance and bill the storage add-on. Uploads currently land in a local
-- ./uploads directory with no per-tenant accounting at all, so this is the
-- minimum needed to make the "base storage allowance" mean anything. Proper
-- object storage with per-tenant prefixes is a separate piece of work; until
-- then, treat this figure as authoritative only insofar as every write path
-- remembers to update it.
-- =====================================================================
ALTER TABLE organizations ADD COLUMN IF NOT EXISTS storage_bytes_used BIGINT NOT NULL DEFAULT 0;

-- =====================================================================
-- Backfill: seed the current month from users.last_login so enforcement and the
-- Account page have a plausible starting count instead of reporting zero active
-- students for every existing tenant.
--
-- This is explicitly an approximation. last_login holds only the most recent
-- login, so a student who logged in this month is counted and everyone else is
-- not; earlier months cannot be reconstructed and are left empty rather than
-- fabricated. From here on the ledger is exact.
-- =====================================================================
INSERT INTO student_activity_period (
    organization_id, student_id, period_ym,
    first_activity_at, last_activity_at, activity_count,
    first_activity_type, activity_types, created_at, updated_at
)
SELECT
    u.organization_id,
    u.id,
    to_char(NOW(), 'YYYY-MM'),
    u.last_login,
    u.last_login,
    1,
    'LOGIN',
    '["LOGIN"]',
    NOW(),
    NOW()
FROM users u
WHERE u.role = 'STUDENT'
  AND u.organization_id IS NOT NULL
  AND u.last_login IS NOT NULL
  AND to_char(u.last_login, 'YYYY-MM') = to_char(NOW(), 'YYYY-MM')
ON CONFLICT (organization_id, student_id, period_ym) DO NOTHING;
