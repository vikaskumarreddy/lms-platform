-- =====================================================================
-- V40: Give a subscription term to any organization that has a plan
--      assigned but no instance behind it.
--
-- WHY THIS IS NEEDED
-- V35 backfilled instances for organizations that had org_subscription_id
-- set at the moment it ran. Two groups slipped through:
--
--   1. Organizations that existed with no plan when V35 ran, and had one
--      assigned afterwards through the organization editor. Until now that
--      path only wrote the column — it never started a term.
--   2. Any organization whose plan was changed directly in the database.
--
-- The symptom is specific and confusing: the platform admin sees a plan on
-- the organizations list (that reads the column), while the tenant's own
-- admin sees "No subscription assigned" on their Account page (that reads
-- the instance, which is where the frozen limits and price actually live).
--
-- This is the same INSERT as V35, re-run for the rows it could not have
-- covered. It is guarded by NOT EXISTS, so it does nothing on a database
-- that is already consistent.
-- =====================================================================

INSERT INTO org_subscription_instances (
    organization_id, plan_id, plan_code, plan_name,
    status, billing_cycle,
    unit_price, currency, tax_inclusive, gst_rate_pct, hsn_sac_code,
    limits_snapshot, entitlements_snapshot,
    period_start, period_end, grace_ends_at,
    auto_renew, change_reason, change_note, is_current,
    activated_at, created_by
)
SELECT
    o.id,
    p.id,
    p.code,
    p.name,
    CASE WHEN o.expiry_date IS NOT NULL AND o.expiry_date < NOW() THEN 'EXPIRED' ELSE 'ACTIVE' END,
    CASE WHEN LOWER(COALESCE(p.period, 'monthly')) = 'yearly' THEN 'YEARLY'
         WHEN LOWER(COALESCE(p.period, 'monthly')) = 'custom' THEN 'CUSTOM'
         ELSE 'MONTHLY' END,
    CASE WHEN LOWER(COALESCE(p.period, 'monthly')) = 'yearly'
         THEN COALESCE(p.price_yearly, p.price_monthly, p.price)
         ELSE COALESCE(p.price_monthly, p.price) END,
    COALESCE(p.currency, 'INR'),
    COALESCE(p.tax_inclusive, FALSE),
    COALESCE(p.gst_rate_pct, 18.00),
    p.hsn_sac_code,
    -- NULL plan limits are omitted rather than written as zero: an absent key
    -- means unlimited, and a zero would mean "no allowance at all".
    COALESCE((
        SELECT jsonb_strip_nulls(jsonb_build_object(
            'MAX_ACTIVE_STUDENTS',     p.max_active_students,
            'MAX_FACULTY_ACCOUNTS',    p.max_faculty_accounts,
            'MAX_BRANCHES',            p.max_branches,
            'MAX_ORGANIZATIONS',       p.max_organizations,
            'STORAGE_GB',              p.storage_gb,
            'INCLUDED_TRAINING_HOURS', p.included_training_hours
        ))::text
    ), '{}'),
    COALESCE(p.entitlements, '{}'),
    COALESCE(o.purchase_date, o.created_at, NOW()),
    -- Derive a term end when the organization has none, so the subscription is
    -- not immediately treated as expired by the clock-based status check.
    COALESCE(
        o.expiry_date,
        CASE WHEN LOWER(COALESCE(p.period, 'monthly')) = 'yearly'
             THEN COALESCE(o.purchase_date, NOW()) + INTERVAL '1 year'
             ELSE COALESCE(o.purchase_date, NOW()) + INTERVAL '1 month' END),
    COALESCE(
        o.expiry_date,
        CASE WHEN LOWER(COALESCE(p.period, 'monthly')) = 'yearly'
             THEN COALESCE(o.purchase_date, NOW()) + INTERVAL '1 year'
             ELSE COALESCE(o.purchase_date, NOW()) + INTERVAL '1 month' END)
        + (COALESCE(p.grace_days, 15) || ' days')::interval,
    TRUE,
    'PLAN_MIGRATION',
    'Backfilled by V40. The organization had a plan assigned but no subscription term, '
        || 'so enforcement and the Account page saw it as unsubscribed.',
    TRUE,
    COALESCE(o.purchase_date, o.created_at, NOW()),
    'system:V40'
FROM organizations o
JOIN org_subscriptions p ON p.id = o.org_subscription_id
WHERE o.org_subscription_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM org_subscription_instances i
      WHERE i.organization_id = o.id AND i.is_current
  );

-- Keep the organization's cached dates consistent with the term just created,
-- so the organizations list and the Account page agree.
UPDATE organizations o
SET purchase_date = i.period_start,
    expiry_date   = i.period_end,
    updated_at    = NOW()
FROM org_subscription_instances i
WHERE i.organization_id = o.id
  AND i.created_by = 'system:V40'
  AND i.is_current
  AND (o.expiry_date IS NULL OR o.purchase_date IS NULL);

-- Record it, so the audit trail explains where these terms came from.
INSERT INTO org_billing_events (organization_id, subscription_instance_id, event_type,
                                to_status, actor, summary, created_at)
SELECT i.organization_id, i.id, 'SUBSCRIBED', i.status, 'system:V40',
       'Subscription term backfilled for an organization that had ' || i.plan_code
           || ' assigned without one.',
       NOW()
FROM org_subscription_instances i
WHERE i.created_by = 'system:V40'
  AND NOT EXISTS (
      SELECT 1 FROM org_billing_events e
      WHERE e.subscription_instance_id = i.id AND e.actor = 'system:V40'
  );
