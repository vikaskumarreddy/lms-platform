-- Organization settings table (tenant-specific configurations like logo, brand colors)
CREATE TABLE organization_settings (
    id             SERIAL PRIMARY KEY,
    organization_id BIGINT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    config_key     VARCHAR(255) NOT NULL,
    config_value   TEXT,
    category       VARCHAR(100) NOT NULL DEFAULT 'GENERAL',
    description    VARCHAR(500),
    is_secret      BOOLEAN NOT NULL DEFAULT FALSE,
    created_at     TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE (organization_id, config_key)
);

CREATE INDEX idx_org_settings_org ON organization_settings(organization_id);
