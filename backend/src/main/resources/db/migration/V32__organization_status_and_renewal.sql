-- V32: Add lifecycle status, purchase/expiry dates, and renewal tracking to organizations.
ALTER TABLE organizations ADD COLUMN status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE';
ALTER TABLE organizations ADD COLUMN purchase_date TIMESTAMP NULL;
ALTER TABLE organizations ADD COLUMN expiry_date TIMESTAMP NULL;
ALTER TABLE organizations ADD COLUMN renewal_count INT NOT NULL DEFAULT 0;

-- Backfill existing rows with defaults.
UPDATE organizations
SET purchase_date = COALESCE(purchase_date, created_at),
    expiry_date   = COALESCE(expiry_date, created_at + INTERVAL '1 year'),
    status        = 'ACTIVE',
    renewal_count = COALESCE(renewal_count, 0)
WHERE status = 'ACTIVE' OR status IS NULL;
