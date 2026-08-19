-- =====================================================================
-- V38: Invoicing, payments, credit notes, coupons and dunning.
--
-- MONEY MOVEMENT, GIVEN THERE IS NO GATEWAY
-- Payment.java and PaymentRepository.java are empty files and Razorpay exists
-- only as unused keys in system_config, so nothing here charges a card. This is
-- an internal ledger: the platform team records what was invoiced and what was
-- received (bank transfer, UPI, cheque, purchase order), which is exactly what
-- the manual/offline and sales-assisted paths need. A gateway can later post
-- into org_payments without any of this changing.
--
-- GST CORRECTNESS
-- Tax is stored per line, not just per invoice, because different lines carry
-- different SAC codes — the subscription is 997331, training is 999293 — and a
-- single invoice-level rate cannot represent that. Whether tax splits into
-- CGST+SGST or is charged as IGST depends on place of supply against the
-- seller's own state, so both the split and the inputs to it are persisted
-- rather than recomputed later from data that may have changed.
--
-- Invoice numbers are sequential per financial year and gapless, which is a
-- statutory requirement; they are issued from a counter table under a row lock
-- rather than from a sequence, because a sequence leaks numbers on rollback.
-- =====================================================================

CREATE TABLE IF NOT EXISTS org_invoices (
    id                       SERIAL PRIMARY KEY,
    organization_id          BIGINT       NOT NULL,
    subscription_instance_id BIGINT,

    -- Statutory identifier, e.g. AX/2026-27/00001. Unique and gapless per FY.
    invoice_number           VARCHAR(40)  NOT NULL,
    -- Indian financial year the number belongs to, e.g. '2026-27'.
    financial_year           VARCHAR(7)   NOT NULL,

    -- DRAFT | ISSUED | PARTIALLY_PAID | PAID | OVERDUE | VOID | CREDITED
    status                   VARCHAR(20)  NOT NULL DEFAULT 'DRAFT',
    -- SUBSCRIPTION | OVERAGE | ADDON | SERVICE | TRAINING | PILOT | PRORATION | MANUAL
    invoice_type             VARCHAR(20)  NOT NULL DEFAULT 'SUBSCRIPTION',

    invoice_date             DATE         NOT NULL DEFAULT CURRENT_DATE,
    due_date                 DATE,
    period_start             DATE,
    period_end               DATE,
    -- Billing month this covers, for overage invoices.
    period_ym                CHAR(7),

    currency                 CHAR(3)      NOT NULL DEFAULT 'INR',
    subtotal                 NUMERIC(14,2) NOT NULL DEFAULT 0,
    discount_total           NUMERIC(14,2) NOT NULL DEFAULT 0,
    taxable_value            NUMERIC(14,2) NOT NULL DEFAULT 0,
    cgst                     NUMERIC(14,2) NOT NULL DEFAULT 0,
    sgst                     NUMERIC(14,2) NOT NULL DEFAULT 0,
    igst                     NUMERIC(14,2) NOT NULL DEFAULT 0,
    total                    NUMERIC(14,2) NOT NULL DEFAULT 0,
    amount_paid              NUMERIC(14,2) NOT NULL DEFAULT 0,
    balance_due              NUMERIC(14,2) NOT NULL DEFAULT 0,

    -- Party details snapshotted at issue. An invoice must reproduce exactly what
    -- was sent, even after the customer changes address or GSTIN.
    seller_gstin             VARCHAR(15),
    seller_legal_name        VARCHAR(255),
    seller_address           TEXT,
    seller_state_code        VARCHAR(2),
    customer_gstin           VARCHAR(15),
    customer_legal_name      VARCHAR(255),
    customer_address         TEXT,
    customer_state_code      VARCHAR(2),
    place_of_supply          VARCHAR(120),
    -- TRUE when tax is payable by the recipient rather than by us.
    is_reverse_charge        BOOLEAN      NOT NULL DEFAULT FALSE,

    po_number                VARCHAR(80),
    coupon_code              VARCHAR(60),
    notes                    TEXT,
    -- Why an invoice was voided; required by the void action.
    void_reason              TEXT,

    issued_at                TIMESTAMP,
    paid_at                  TIMESTAMP,
    voided_at                TIMESTAMP,

    created_at               TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at               TIMESTAMP    NOT NULL DEFAULT NOW(),
    created_by               VARCHAR(255),

    CONSTRAINT fk_inv_organization FOREIGN KEY (organization_id)
        REFERENCES organizations (id) ON DELETE CASCADE,
    CONSTRAINT fk_inv_instance FOREIGN KEY (subscription_instance_id)
        REFERENCES org_subscription_instances (id) ON DELETE SET NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS uk_invoices_number ON org_invoices (invoice_number);
CREATE INDEX IF NOT EXISTS idx_invoices_org    ON org_invoices (organization_id, invoice_date DESC);
CREATE INDEX IF NOT EXISTS idx_invoices_status ON org_invoices (status, due_date);

-- Per-line tax, because SAC codes differ between subscription and training lines.
CREATE TABLE IF NOT EXISTS org_invoice_lines (
    id             SERIAL PRIMARY KEY,
    invoice_id     BIGINT       NOT NULL,
    line_no        INT          NOT NULL DEFAULT 1,

    -- PLAN | ADDON | OVERAGE | SERVICE | TRAINING | PRORATION | CREDIT | DISCOUNT
    line_type      VARCHAR(20)  NOT NULL DEFAULT 'PLAN',
    description    VARCHAR(500) NOT NULL,
    hsn_sac_code   VARCHAR(10),

    qty            NUMERIC(12,2) NOT NULL DEFAULT 1,
    unit_label     VARCHAR(60),
    unit_price     NUMERIC(14,2) NOT NULL DEFAULT 0,
    discount       NUMERIC(14,2) NOT NULL DEFAULT 0,
    taxable_value  NUMERIC(14,2) NOT NULL DEFAULT 0,

    tax_rate_pct   NUMERIC(5,2)  NOT NULL DEFAULT 18.00,
    cgst           NUMERIC(14,2) NOT NULL DEFAULT 0,
    sgst           NUMERIC(14,2) NOT NULL DEFAULT 0,
    igst           NUMERIC(14,2) NOT NULL DEFAULT 0,
    line_total     NUMERIC(14,2) NOT NULL DEFAULT 0,

    addon_code     VARCHAR(60),
    -- How the figure was arrived at, e.g. the proration derivation. Kept so a
    -- disputed amount can be explained without recomputing from moved dates.
    calculation    TEXT,

    CONSTRAINT fk_line_invoice FOREIGN KEY (invoice_id)
        REFERENCES org_invoices (id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_lines_invoice ON org_invoice_lines (invoice_id, line_no);

-- Money actually received. Recorded by the platform team; a gateway can post here later.
CREATE TABLE IF NOT EXISTS org_payments (
    id                 SERIAL PRIMARY KEY,
    organization_id    BIGINT       NOT NULL,
    invoice_id         BIGINT,

    amount             NUMERIC(14,2) NOT NULL,
    currency           CHAR(3)      NOT NULL DEFAULT 'INR',
    -- BANK_TRANSFER | UPI | CHEQUE | CASH | CARD | GATEWAY | ADJUSTMENT
    method             VARCHAR(20)  NOT NULL DEFAULT 'BANK_TRANSFER',
    -- RECORDED | CLEARED | BOUNCED | REFUNDED
    status             VARCHAR(20)  NOT NULL DEFAULT 'CLEARED',

    reference          VARCHAR(160),
    -- Populated only when a gateway is eventually integrated.
    gateway_payment_id VARCHAR(120),
    paid_at            TIMESTAMP    NOT NULL DEFAULT NOW(),
    recorded_by        VARCHAR(255),
    notes              TEXT,
    created_at         TIMESTAMP    NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_pay_organization FOREIGN KEY (organization_id)
        REFERENCES organizations (id) ON DELETE CASCADE,
    CONSTRAINT fk_pay_invoice FOREIGN KEY (invoice_id)
        REFERENCES org_invoices (id) ON DELETE SET NULL,
    CONSTRAINT ck_pay_amount CHECK (amount <> 0)
);

CREATE INDEX IF NOT EXISTS idx_payments_org     ON org_payments (organization_id, paid_at DESC);
CREATE INDEX IF NOT EXISTS idx_payments_invoice ON org_payments (invoice_id);

-- Credit notes. An issued invoice is never edited or deleted — a correction is a
-- credit note against it, which is both the statutory expectation and the only
-- way an audit trail survives a mistake.
CREATE TABLE IF NOT EXISTS org_credit_notes (
    id                  SERIAL PRIMARY KEY,
    organization_id     BIGINT       NOT NULL,
    invoice_id          BIGINT,

    credit_note_number  VARCHAR(40)  NOT NULL,
    financial_year      VARCHAR(7)   NOT NULL,
    issue_date          DATE         NOT NULL DEFAULT CURRENT_DATE,
    -- DOWNGRADE | CANCELLATION | BILLING_ERROR | GOODWILL | PILOT_CREDIT | OTHER
    reason_code         VARCHAR(30)  NOT NULL DEFAULT 'OTHER',
    reason              TEXT,

    currency            CHAR(3)      NOT NULL DEFAULT 'INR',
    taxable_value       NUMERIC(14,2) NOT NULL DEFAULT 0,
    cgst                NUMERIC(14,2) NOT NULL DEFAULT 0,
    sgst                NUMERIC(14,2) NOT NULL DEFAULT 0,
    igst                NUMERIC(14,2) NOT NULL DEFAULT 0,
    total               NUMERIC(14,2) NOT NULL DEFAULT 0,
    -- TRUE once offset against an invoice or refunded.
    is_applied          BOOLEAN      NOT NULL DEFAULT FALSE,
    applied_at          TIMESTAMP,

    issued_by           VARCHAR(255),
    created_at          TIMESTAMP    NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_cn_organization FOREIGN KEY (organization_id)
        REFERENCES organizations (id) ON DELETE CASCADE,
    CONSTRAINT fk_cn_invoice FOREIGN KEY (invoice_id)
        REFERENCES org_invoices (id) ON DELETE SET NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS uk_credit_notes_number ON org_credit_notes (credit_note_number);
CREATE INDEX IF NOT EXISTS idx_credit_notes_org ON org_credit_notes (organization_id, issue_date DESC);

-- Gapless per-financial-year numbering.
--
-- A counter table rather than a Postgres sequence: sequences are non
-- transactional and leak numbers whenever a transaction rolls back, which would
-- produce gaps in a statutory series. Allocation takes a row lock (SELECT ...
-- FOR UPDATE), so concurrent issuance serialises on that row and either both
-- numbers are used or neither is.
CREATE TABLE IF NOT EXISTS org_document_sequences (
    doc_type       VARCHAR(20) NOT NULL,   -- INVOICE | CREDIT_NOTE
    financial_year VARCHAR(7)  NOT NULL,
    last_number    BIGINT      NOT NULL DEFAULT 0,
    prefix         VARCHAR(20) NOT NULL DEFAULT 'AX',
    updated_at     TIMESTAMP   NOT NULL DEFAULT NOW(),
    PRIMARY KEY (doc_type, financial_year)
);

-- Coupons and promotional pricing.
CREATE TABLE IF NOT EXISTS org_coupons (
    id                    SERIAL PRIMARY KEY,
    code                  VARCHAR(60)  NOT NULL,
    description           TEXT,

    -- PERCENT | AMOUNT
    discount_type         VARCHAR(10)  NOT NULL DEFAULT 'PERCENT',
    value                 NUMERIC(12,2) NOT NULL,
    -- Caps a percentage discount so "50% off" on an Enterprise deal cannot cost
    -- more than intended.
    max_discount_amount   NUMERIC(12,2),
    currency              CHAR(3)      NOT NULL DEFAULT 'INR',

    -- JSON array of plan codes; null means any plan.
    applies_to_plan_codes TEXT,
    -- TRUE when the discount applies only to the first billing period.
    first_period_only     BOOLEAN      NOT NULL DEFAULT TRUE,

    max_redemptions       INT,
    redemptions_used      INT          NOT NULL DEFAULT 0,
    -- Caps repeat use by the same tenant.
    max_per_organization  INT          NOT NULL DEFAULT 1,

    valid_from            TIMESTAMP,
    valid_to              TIMESTAMP,
    is_active             BOOLEAN      NOT NULL DEFAULT TRUE,

    created_at            TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMP    NOT NULL DEFAULT NOW(),
    created_by            VARCHAR(255),

    CONSTRAINT ck_coupon_value CHECK (value > 0)
);

CREATE UNIQUE INDEX IF NOT EXISTS uk_coupons_code ON org_coupons (UPPER(code));

CREATE TABLE IF NOT EXISTS org_coupon_redemptions (
    id                       SERIAL PRIMARY KEY,
    coupon_id                BIGINT      NOT NULL,
    coupon_code              VARCHAR(60) NOT NULL,
    organization_id          BIGINT      NOT NULL,
    subscription_instance_id BIGINT,
    invoice_id               BIGINT,
    discount_applied         NUMERIC(12,2) NOT NULL DEFAULT 0,
    redeemed_at              TIMESTAMP   NOT NULL DEFAULT NOW(),
    redeemed_by              VARCHAR(255),

    CONSTRAINT fk_redeem_coupon FOREIGN KEY (coupon_id)
        REFERENCES org_coupons (id) ON DELETE CASCADE,
    CONSTRAINT fk_redeem_organization FOREIGN KEY (organization_id)
        REFERENCES organizations (id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_redeem_org ON org_coupon_redemptions (organization_id, coupon_id);

-- Dunning: the escalating sequence of reminders on an overdue invoice.
--
-- Every attempt is recorded so the same reminder is not sent twice, and so that
-- suspending a tenant for non-payment can be justified with a list of what was
-- sent and when.
CREATE TABLE IF NOT EXISTS org_dunning_events (
    id              SERIAL PRIMARY KEY,
    organization_id BIGINT      NOT NULL,
    invoice_id      BIGINT,

    attempt_no      INT         NOT NULL DEFAULT 1,
    -- REMINDER_BEFORE_DUE | REMINDER_OVERDUE | ESCALATION
    -- | SUSPENSION_WARNING | SUSPENDED
    event_type      VARCHAR(30) NOT NULL,
    -- EMAIL | SMS | WHATSAPP | IN_APP | MANUAL
    channel         VARCHAR(20) NOT NULL DEFAULT 'EMAIL',
    recipient       VARCHAR(255),
    subject         VARCHAR(255),
    -- SENT | FAILED | SKIPPED
    status          VARCHAR(20) NOT NULL DEFAULT 'SENT',
    failure_reason  TEXT,

    sent_at         TIMESTAMP   NOT NULL DEFAULT NOW(),
    next_action_at  TIMESTAMP,
    payload         TEXT,

    CONSTRAINT fk_dunning_organization FOREIGN KEY (organization_id)
        REFERENCES organizations (id) ON DELETE CASCADE,
    CONSTRAINT fk_dunning_invoice FOREIGN KEY (invoice_id)
        REFERENCES org_invoices (id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_dunning_invoice ON org_dunning_events (invoice_id, attempt_no);
CREATE INDEX IF NOT EXISTS idx_dunning_org     ON org_dunning_events (organization_id, sent_at DESC);
-- Stops the same escalation step firing twice for one invoice.
CREATE UNIQUE INDEX IF NOT EXISTS uk_dunning_step
    ON org_dunning_events (invoice_id, event_type) WHERE invoice_id IS NOT NULL;

-- Seller identity for invoices. Stored as configuration so it can be corrected
-- without a deploy; an invoice missing the seller GSTIN is not filable.
--
-- Note the table is system_configs (plural), with is_secret rather than
-- is_editable — see V19.
INSERT INTO system_configs (config_key, config_value, category, description, is_secret)
SELECT seed.config_key, seed.config_value, seed.category, seed.description, seed.is_secret
FROM (VALUES
    ('billing.seller.legalName', '', 'BILLING', 'Registered legal name shown on invoices', false),
    ('billing.seller.gstin', '', 'BILLING', 'Our GSTIN, printed on every invoice', false),
    ('billing.seller.address', '', 'BILLING', 'Registered address shown on invoices', false),
    ('billing.seller.stateCode', '', 'BILLING', 'Our GST state code — decides CGST+SGST vs IGST', false),
    ('billing.invoice.prefix', 'AX', 'BILLING', 'Invoice number prefix, e.g. AX/2026-27/00001', false),
    ('billing.invoice.dueDays', '15', 'BILLING', 'Days from issue until an invoice is due', false),
    ('billing.dunning.enabled', 'false', 'BILLING', 'Send automated overdue reminders', false)
) AS seed(config_key, config_value, category, description, is_secret)
WHERE NOT EXISTS (
    SELECT 1 FROM system_configs c WHERE c.config_key = seed.config_key
);
