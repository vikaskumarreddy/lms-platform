-- =====================================================================
-- V37: Branches (campuses) inside an organization.
--
-- "Multiple branches" is sold on Platform Plus and above, but no branch concept
-- existed anywhere in the schema, so MAX_BRANCHES had nothing to count and the
-- feature was unenforceable.
--
-- WHY A TABLE INSIDE THE ORGANIZATION, NOT SEPARATE ORGANIZATIONS
-- The alternative was to model each branch as its own tenant. That was rejected:
-- tenant isolation is per-organization, so splitting a customer across
-- organizations would fragment their students, courses, reports and billing into
-- separate silos, break "one login sees all branches", and leave us invoicing one
-- customer several times. A branch is a grouping WITHIN a tenant's data, which is
-- what customers actually mean by it.
--
-- branch_id is nullable everywhere on purpose. Single-branch academies — every
-- Platform tenant — never touch it, and existing rows stay valid without a
-- backfill.
--
-- Unlike the billing tables, `branches` IS tenant-scoped: it holds ordinary
-- academy data that a tenant admin reads and writes, so it carries
-- organization_id as a Hibernate @TenantId discriminator column like users,
-- courses and batches do. Cross-organization branch counts for the platform are
-- taken with native queries.
-- =====================================================================

CREATE TABLE IF NOT EXISTS branches (
    id               SERIAL PRIMARY KEY,
    organization_id  BIGINT       NOT NULL,

    name             VARCHAR(200) NOT NULL,
    -- Short human code used in listings and reports, e.g. 'HYD-01'.
    code             VARCHAR(40),

    address          TEXT,
    city             VARCHAR(120),
    state            VARCHAR(120),
    pincode          VARCHAR(10),
    phone            VARCHAR(30),
    email            VARCHAR(255),
    contact_person   VARCHAR(160),

    -- Marks the original/head branch, created implicitly for existing tenants.
    is_primary       BOOLEAN      NOT NULL DEFAULT FALSE,
    is_active        BOOLEAN      NOT NULL DEFAULT TRUE,

    created_at       TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMP    NOT NULL DEFAULT NOW(),
    created_by       VARCHAR(255),
    updated_by       VARCHAR(255),
    version          BIGINT       NOT NULL DEFAULT 0,

    CONSTRAINT fk_branches_organization FOREIGN KEY (organization_id)
        REFERENCES organizations (id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_branches_org ON branches (organization_id, is_active);
-- Branch codes are unique per tenant, not globally: two academies may both have
-- a 'MAIN' branch.
CREATE UNIQUE INDEX IF NOT EXISTS uk_branches_org_code
    ON branches (organization_id, code) WHERE code IS NOT NULL;
-- At most one primary branch per tenant.
CREATE UNIQUE INDEX IF NOT EXISTS uk_branches_org_primary
    ON branches (organization_id) WHERE is_primary;

-- Associate people and batches with a branch. Nullable: unset means
-- organization-wide, which is correct for every single-branch tenant.
ALTER TABLE users   ADD COLUMN IF NOT EXISTS branch_id BIGINT;
ALTER TABLE batches ADD COLUMN IF NOT EXISTS branch_id BIGINT;

CREATE INDEX IF NOT EXISTS idx_users_branch   ON users (branch_id) WHERE branch_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_batches_branch ON batches (branch_id) WHERE branch_id IS NOT NULL;

-- Deliberately ON DELETE SET NULL rather than CASCADE: deleting a branch must
-- never delete the students or batches attached to it. They fall back to being
-- organization-wide, which is recoverable; cascading would destroy academy data
-- because someone tidied up a campus record.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_users_branch') THEN
        ALTER TABLE users ADD CONSTRAINT fk_users_branch
            FOREIGN KEY (branch_id) REFERENCES branches (id) ON DELETE SET NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_batches_branch') THEN
        ALTER TABLE batches ADD CONSTRAINT fk_batches_branch
            FOREIGN KEY (branch_id) REFERENCES branches (id) ON DELETE SET NULL;
    END IF;
END $$;

-- Give every existing organization a primary branch, so the branch count is 1
-- rather than 0 from the outset. Reporting a tenant as having zero branches
-- would be wrong, and would make the first branch they add look like their
-- second against a limit of 1.
INSERT INTO branches (organization_id, name, code, is_primary, is_active, created_by)
SELECT o.id, o.name || ' (Main)', 'MAIN', TRUE, TRUE, 'system:V37'
FROM organizations o
WHERE NOT EXISTS (
    SELECT 1 FROM branches b WHERE b.organization_id = o.id
);
