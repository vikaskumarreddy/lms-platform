-- Add organization_id to users table and backfill existing rows to the default org
ALTER TABLE users ADD COLUMN organization_id BIGINT;

-- Backfill all existing users to the default 'axisora' organization
UPDATE users SET organization_id = (SELECT id FROM organizations WHERE slug = 'axisora')
WHERE organization_id IS NULL;

-- Make the column non-nullable after backfill
ALTER TABLE users ALTER COLUMN organization_id SET NOT NULL;

-- Index for tenant-scoped queries
CREATE INDEX idx_users_organization_id ON users(organization_id);
