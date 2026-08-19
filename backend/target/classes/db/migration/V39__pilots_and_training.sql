-- =====================================================================
-- V39: Assisted pilots and training agreements.
--
-- PILOTS
-- The pilot is priced at 15,000-30,000 for work — setup, faculty onboarding,
-- data import, configuration, support, a usage review — that is realistically
-- 15-25 person-hours. It only makes sense as customer acquisition if it
-- converts, so the model records the two things that make conversion likely:
-- a hard decision date, and the fee credited in full against the first annual
-- invoice. The credit is a real credit note, not a discount, so the pilot
-- revenue and the credit both appear in the books.
--
-- Success is measured against targets agreed up front rather than judged
-- afterwards, which is what org_pilot_metrics is for.
--
-- TRAINING AGREEMENTS
-- Four charging models were specified, and each fails differently without a
-- written scope, so the scope fields are on the agreement rather than in a
-- document nobody can query: subjects, batches, class size, sessions,
-- preparation time, assessments, faculty hours and the replacement policy.
--
-- Revenue share carries extra guards. A share of the academy's fee income
-- cannot be computed unless their collections run through this platform, and
-- there is no payment gateway integrated at all — so the model requires an
-- explicit revenue base definition, a flag confirming collections flow through
-- us, and a minimum guarantee so trainers are not funded for a programme that
-- fails to enrol.
-- =====================================================================

CREATE TABLE IF NOT EXISTS org_pilots (
    id                       SERIAL PRIMARY KEY,
    organization_id          BIGINT       NOT NULL,
    subscription_instance_id BIGINT,

    pilot_fee                NUMERIC(12,2) NOT NULL DEFAULT 25000,
    currency                 CHAR(3)      NOT NULL DEFAULT 'INR',
    starts_on                DATE         NOT NULL DEFAULT CURRENT_DATE,
    ends_on                  DATE         NOT NULL,
    -- The date the academy must decide by. Without one a pilot drifts, and a
    -- 90-day pilot is long enough to run a full batch and leave.
    decision_due_on          DATE,

    -- ACTIVE | CONVERTED | LAPSED | EXTENDED | CANCELLED
    status                   VARCHAR(20)  NOT NULL DEFAULT 'ACTIVE',

    -- Fee handling on conversion. Credited in full against the first annual
    -- invoice, which makes the pilot effectively a deposit; non-refundable
    -- otherwise.
    fee_invoice_id           BIGINT,
    fee_credited             BOOLEAN      NOT NULL DEFAULT FALSE,
    credit_note_id           BIGINT,
    converted_instance_id    BIGINT,
    converted_at             TIMESTAMP,

    -- What was agreed to be delivered during the pilot.
    scope_notes              TEXT,
    students_to_import       INT,
    courses_to_import        INT,
    faculty_to_onboard       INT,
    support_terms            TEXT,

    owner                    VARCHAR(160),
    notes                    TEXT,

    created_at               TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at               TIMESTAMP    NOT NULL DEFAULT NOW(),
    created_by               VARCHAR(255),

    CONSTRAINT fk_pilot_organization FOREIGN KEY (organization_id)
        REFERENCES organizations (id) ON DELETE CASCADE,
    CONSTRAINT ck_pilot_dates CHECK (ends_on >= starts_on)
);

CREATE INDEX IF NOT EXISTS idx_pilots_org    ON org_pilots (organization_id, status);
CREATE INDEX IF NOT EXISTS idx_pilots_status ON org_pilots (status, decision_due_on);
-- One live pilot per organization.
CREATE UNIQUE INDEX IF NOT EXISTS uk_pilots_active_per_org
    ON org_pilots (organization_id) WHERE status = 'ACTIVE';

-- Success measured against targets agreed at the start, so conversion is a
-- conversation about evidence rather than impressions.
CREATE TABLE IF NOT EXISTS org_pilot_metrics (
    id            SERIAL PRIMARY KEY,
    pilot_id      BIGINT       NOT NULL,

    -- STUDENT_ACTIVATION | COURSE_COMPLETION | ASSESSMENT_PARTICIPATION
    -- | ADMIN_HOURS_SAVED | COLLECTION_IMPROVEMENT | PLACEMENT_APPLICATIONS
    -- | MOCK_INTERVIEWS | INTERVIEWS | SELECTIONS
    metric_key    VARCHAR(40)  NOT NULL,
    label         VARCHAR(160) NOT NULL,
    -- COUNT | PERCENT | HOURS | CURRENCY
    unit          VARCHAR(20)  NOT NULL DEFAULT 'COUNT',

    target_value  NUMERIC(12,2),
    actual_value  NUMERIC(12,2),
    -- TRUE when the platform fills this in itself rather than someone typing it.
    auto_measured BOOLEAN      NOT NULL DEFAULT FALSE,
    measured_at   TIMESTAMP,
    notes         TEXT,

    CONSTRAINT fk_metric_pilot FOREIGN KEY (pilot_id)
        REFERENCES org_pilots (id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS uk_pilot_metric ON org_pilot_metrics (pilot_id, metric_key);

-- =====================================================================
-- Training agreements
-- =====================================================================
CREATE TABLE IF NOT EXISTS org_training_agreements (
    id                          SERIAL PRIMARY KEY,
    organization_id             BIGINT       NOT NULL,
    title                       VARCHAR(200) NOT NULL,

    -- PER_STUDENT_PROGRAM | PER_FACULTY_HOUR | MONTHLY_RETAINER | REVENUE_SHARE
    billing_model               VARCHAR(30)  NOT NULL,
    currency                    CHAR(3)      NOT NULL DEFAULT 'INR',

    -- PER_STUDENT_PROGRAM: 1,500-4,000 per student per programme.
    rate_per_student            NUMERIC(12,2),
    -- PER_FACULTY_HOUR: 1,500-4,000 per hour.
    rate_per_hour               NUMERIC(12,2),
    -- MONTHLY_RETAINER: 75,000-2,00,000 for a stated number of hours. A retainer
    -- without an hour count cannot be billed or defended, so both are captured.
    retainer_amount             NUMERIC(12,2),
    retainer_included_hours     NUMERIC(8,2),

    -- REVENUE_SHARE: 15-30%.
    revenue_share_pct           NUMERIC(5,2),
    -- Mandatory for revenue share: exactly what the percentage applies to, e.g.
    -- "gross programme fees collected, net of taxes and refunds".
    revenue_base_definition     TEXT,
    -- Revenue share is unverifiable unless fee collection runs through the
    -- platform, and no payment gateway is integrated today.
    collections_through_platform BOOLEAN     NOT NULL DEFAULT FALSE,
    -- Floor payable regardless of enrolment, so trainers are not funded for a
    -- programme that fails to fill.
    minimum_guarantee           NUMERIC(12,2),

    -- Scope. Every field here exists because its absence causes a dispute.
    subjects                    TEXT,           -- JSON array
    batches                     TEXT,           -- JSON array
    class_size                  INT,
    sessions_count              INT,
    session_duration_minutes    INT,
    prep_time_hours             NUMERIC(8,2),
    assessments_count           INT,
    faculty_hours_committed     NUMERIC(8,2),
    -- How quickly a trainer is replaced, and on whose cost.
    replacement_policy          TEXT         NOT NULL DEFAULT '',

    starts_on                   DATE,
    ends_on                     DATE,
    -- DRAFT | ACTIVE | COMPLETED | TERMINATED
    status                      VARCHAR(20)  NOT NULL DEFAULT 'DRAFT',

    hsn_sac_code                VARCHAR(10)  DEFAULT '999293',
    gst_rate_pct                NUMERIC(5,2) NOT NULL DEFAULT 18.00,
    notes                       TEXT,

    created_at                  TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at                  TIMESTAMP    NOT NULL DEFAULT NOW(),
    created_by                  VARCHAR(255),

    CONSTRAINT fk_training_organization FOREIGN KEY (organization_id)
        REFERENCES organizations (id) ON DELETE CASCADE,

    -- Enforce the guards at the database, so an agreement cannot reach ACTIVE
    -- missing the terms that make it billable.
    CONSTRAINT ck_training_revenue_share CHECK (
        billing_model <> 'REVENUE_SHARE'
        OR status = 'DRAFT'
        OR (revenue_share_pct IS NOT NULL
            AND revenue_base_definition IS NOT NULL
            AND length(trim(revenue_base_definition)) > 0
            AND collections_through_platform = TRUE)
    ),
    CONSTRAINT ck_training_retainer CHECK (
        billing_model <> 'MONTHLY_RETAINER'
        OR status = 'DRAFT'
        OR (retainer_amount IS NOT NULL AND retainer_included_hours IS NOT NULL)
    ),
    CONSTRAINT ck_training_replacement CHECK (
        status = 'DRAFT' OR length(trim(replacement_policy)) > 0
    )
);

CREATE INDEX IF NOT EXISTS idx_training_org ON org_training_agreements (organization_id, status);

-- Delivered hours. Evidence for an invoice, and the drawdown against the plan's
-- included training hours — Managed Academy bundles 20 a month, and those are
-- consumed before any purchased hour is billed. Without this table the base fee
-- and the hourly rate would both charge for the same work.
CREATE TABLE IF NOT EXISTS org_training_worklog (
    id                SERIAL PRIMARY KEY,
    agreement_id      BIGINT       NOT NULL,
    organization_id   BIGINT       NOT NULL,

    work_date         DATE         NOT NULL DEFAULT CURRENT_DATE,
    -- Billing month, so drawdown against the monthly allowance is a simple sum.
    period_ym         CHAR(7)      NOT NULL,

    faculty_user_id   BIGINT,
    faculty_name      VARCHAR(160),
    batch_id          BIGINT,
    subject           VARCHAR(200),
    -- CLASS | PREPARATION | ASSESSMENT | MENTORING | MOCK_INTERVIEW | ADMIN
    session_type      VARCHAR(30)  NOT NULL DEFAULT 'CLASS',

    hours             NUMERIC(6,2) NOT NULL,
    students_count    INT,
    notes             TEXT,

    -- FALSE for work covered by the plan's included hours or a retainer.
    billable          BOOLEAN      NOT NULL DEFAULT TRUE,
    -- Set once billed, so the same hour is never invoiced twice.
    invoiced_invoice_id BIGINT,
    rate_applied      NUMERIC(12,2),

    created_at        TIMESTAMP    NOT NULL DEFAULT NOW(),
    created_by        VARCHAR(255),

    CONSTRAINT fk_worklog_agreement FOREIGN KEY (agreement_id)
        REFERENCES org_training_agreements (id) ON DELETE CASCADE,
    CONSTRAINT fk_worklog_organization FOREIGN KEY (organization_id)
        REFERENCES organizations (id) ON DELETE CASCADE,
    CONSTRAINT ck_worklog_hours CHECK (hours > 0)
);

CREATE INDEX IF NOT EXISTS idx_worklog_org_period ON org_training_worklog (organization_id, period_ym);
CREATE INDEX IF NOT EXISTS idx_worklog_agreement  ON org_training_worklog (agreement_id, work_date DESC);
CREATE INDEX IF NOT EXISTS idx_worklog_unbilled   ON org_training_worklog (organization_id, billable)
    WHERE invoiced_invoice_id IS NULL;
