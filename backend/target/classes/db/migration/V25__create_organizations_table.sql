-- Organizations (tenants) for SaaS multi-tenancy
CREATE TABLE organizations (
    id           SERIAL PRIMARY KEY,
    name         VARCHAR(255) NOT NULL,
    slug         VARCHAR(100) NOT NULL UNIQUE,
    domain       VARCHAR(255) UNIQUE,
    logo_url     VARCHAR(500),
    is_active    BOOLEAN NOT NULL DEFAULT TRUE,
    plan_id      BIGINT,
    settings     TEXT,
    created_at   TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Seed a default organization for existing data
INSERT INTO organizations (name, slug, domain, is_active, plan_id, settings)
SELECT 'Axisora', 'axisora', 'localhost', TRUE, NULL, '{}'
WHERE NOT EXISTS (SELECT 1 FROM organizations WHERE slug = 'axisora');
