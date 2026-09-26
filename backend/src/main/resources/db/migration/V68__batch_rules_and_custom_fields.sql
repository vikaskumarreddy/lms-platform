-- V68: Batch Rules and Custom Fields for Registration Customization

CREATE TABLE IF NOT EXISTS batch_rules (
    id              BIGSERIAL PRIMARY KEY,
    organization_id BIGINT,
    name            VARCHAR(255) NOT NULL,
    plan_id         BIGINT NOT NULL,
    batch_id        BIGINT NOT NULL,
    priority        INT DEFAULT 0,
    is_active       BOOLEAN DEFAULT TRUE,
    conditions      TEXT,
    created_at      TIMESTAMP,
    updated_at      TIMESTAMP,
    created_by      VARCHAR(255),
    updated_by      VARCHAR(255),
    version         BIGINT DEFAULT 0,
    CONSTRAINT fk_batch_rules_org  FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
    CONSTRAINT fk_batch_rules_plan FOREIGN KEY (plan_id)         REFERENCES subscription_plans(id) ON DELETE CASCADE,
    CONSTRAINT fk_batch_rules_batch FOREIGN KEY (batch_id)       REFERENCES batches(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_batch_rules_org       ON batch_rules(organization_id);
CREATE INDEX IF NOT EXISTS idx_batch_rules_plan      ON batch_rules(organization_id, plan_id);
CREATE INDEX IF NOT EXISTS idx_batch_rules_active    ON batch_rules(organization_id, plan_id, is_active, priority);

ALTER TABLE users ADD COLUMN IF NOT EXISTS custom_fields TEXT;
