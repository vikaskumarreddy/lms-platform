-- Additional payment gateways (PayU, Cashfree) alongside the existing Razorpay
-- integration, which is untouched (org_razorpay_config keeps working exactly as
-- before). Nullable/additive; active_gateway = NULL is treated as RAZORPAY by
-- the application layer, so no existing organization's payment flow changes.
ALTER TABLE organizations ADD COLUMN active_gateway VARCHAR(30) NULL;

CREATE TABLE org_payment_gateway_config (
    id BIGSERIAL PRIMARY KEY,
    organization_id BIGINT NULL,
    gateway VARCHAR(30) NOT NULL,
    credentials_json TEXT NULL,
    amount_per_student BIGINT NULL,
    payment_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NULL,
    updated_at TIMESTAMP NULL,
    created_by VARCHAR(255) NULL,
    updated_by VARCHAR(255) NULL,
    version BIGINT NULL,
    CONSTRAINT uq_org_payment_gateway_config UNIQUE (organization_id, gateway)
);
