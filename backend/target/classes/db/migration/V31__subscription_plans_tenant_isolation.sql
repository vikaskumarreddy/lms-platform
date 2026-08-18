-- =====================================================================
-- V31: Make subscription_plans tenant-scoped.
-- SubscriptionPlan was previously a GlobalEntity (platform-wide catalog).
-- It now extends BaseEntity (@TenantId on organization_id), so Hibernate's
-- DISCRIMINATOR multi-tenancy injects an organization_id predicate into every
-- query. This column must therefore exist in the schema.
-- =====================================================================

ALTER TABLE subscription_plans ADD COLUMN IF NOT EXISTS organization_id BIGINT;

-- Backfill existing (previously global) plans to the default/seed org (axisora,
-- id 1) so they remain visible to at least one tenant. New plans created inside
-- an org get their organization_id stamped automatically by BaseEntity.
UPDATE subscription_plans
SET organization_id = 1
WHERE organization_id IS NULL;

-- =====================================================================
-- V31: index on organization_id for the tenant-filtered lookups
-- =====================================================================
CREATE INDEX IF NOT EXISTS idx_subscription_plans_org
    ON subscription_plans (organization_id);
