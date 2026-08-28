-- Parent/guardian contact fields on users, used for daily-attendance absentee
-- alerts and other parent-facing notifications. Additive and nullable;
-- existing students are unaffected and default to notifying via PUSH.
ALTER TABLE users ADD COLUMN parent_name VARCHAR(255) NULL;
ALTER TABLE users ADD COLUMN parent_phone VARCHAR(30) NULL;
ALTER TABLE users ADD COLUMN parent_email VARCHAR(255) NULL;
ALTER TABLE users ADD COLUMN notify_medium VARCHAR(20) NOT NULL DEFAULT 'PUSH';

-- Per-organization messaging vendor configuration (SMS / WhatsApp), one row
-- per (organization, channel). Mirrors org_razorpay_config's shape: secrets
-- live in credentials_json and are masked on read by the controller layer.
CREATE TABLE org_messaging_config (
    id BIGSERIAL PRIMARY KEY,
    organization_id BIGINT NULL,
    channel VARCHAR(20) NOT NULL,
    vendor VARCHAR(30) NOT NULL,
    credentials_json TEXT NULL,
    enabled BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NULL,
    updated_at TIMESTAMP NULL,
    created_by VARCHAR(255) NULL,
    updated_by VARCHAR(255) NULL,
    version BIGINT NULL,
    CONSTRAINT uq_org_messaging_channel UNIQUE (organization_id, channel)
);
