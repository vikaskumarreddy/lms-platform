-- =====================================================================
-- V30: Tenant isolation – add organization_id to the remaining BaseEntity
-- tables that V29 missed (batches, certificates, interview_slots, notes,
-- notifications, placement_drives, progress, questions, student_placements,
-- subscriptions). Every entity extending BaseEntity has a Hibernate
-- @Filter("tenantFilter") on organization_id, so Hibernate always includes
-- this column in generated SQL — leaving it out of the schema causes a
-- "column ... organization_id does not exist" error at runtime (as seen for
-- "subscriptions").
-- =====================================================================

-- =====================================================================
-- V30: add organization_id column to tenant tables
-- =====================================================================

ALTER TABLE batches ADD COLUMN IF NOT EXISTS organization_id BIGINT;
ALTER TABLE certificates ADD COLUMN IF NOT EXISTS organization_id BIGINT;
ALTER TABLE interview_slots ADD COLUMN IF NOT EXISTS organization_id BIGINT;
ALTER TABLE notes ADD COLUMN IF NOT EXISTS organization_id BIGINT;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS organization_id BIGINT;
ALTER TABLE placement_drives ADD COLUMN IF NOT EXISTS organization_id BIGINT;
ALTER TABLE progress ADD COLUMN IF NOT EXISTS organization_id BIGINT;
ALTER TABLE questions ADD COLUMN IF NOT EXISTS organization_id BIGINT;
ALTER TABLE student_placements ADD COLUMN IF NOT EXISTS organization_id BIGINT;
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS organization_id BIGINT;

-- =====================================================================
-- V30: backfill organization_id from created_by (matches the user who
-- created the row), falling back to the default org (1) when unresolved
-- =====================================================================

-- batches
UPDATE batches t
SET organization_id = COALESCE(
    (SELECT u.organization_id FROM users u WHERE u.email = t.created_by LIMIT 1),
    1)
WHERE t.organization_id IS NULL;

-- certificates (has a direct user_id column, more reliable than created_by)
UPDATE certificates t
SET organization_id = COALESCE(
    (SELECT u.organization_id FROM users u WHERE u.id = t.user_id LIMIT 1),
    (SELECT u.organization_id FROM users u WHERE u.email = t.created_by LIMIT 1),
    1)
WHERE t.organization_id IS NULL;

-- interview_slots
UPDATE interview_slots t
SET organization_id = COALESCE(
    (SELECT u.organization_id FROM users u WHERE u.email = t.created_by LIMIT 1),
    1)
WHERE t.organization_id IS NULL;

-- notes (has a direct user_id column)
UPDATE notes t
SET organization_id = COALESCE(
    (SELECT u.organization_id FROM users u WHERE u.id = t.user_id LIMIT 1),
    (SELECT u.organization_id FROM users u WHERE u.email = t.created_by LIMIT 1),
    1)
WHERE t.organization_id IS NULL;

-- notifications (has a direct user_id column, nullable for broadcasts)
UPDATE notifications t
SET organization_id = COALESCE(
    (SELECT u.organization_id FROM users u WHERE u.id = t.user_id LIMIT 1),
    (SELECT u.organization_id FROM users u WHERE u.email = t.created_by LIMIT 1),
    1)
WHERE t.organization_id IS NULL;

-- placement_drives
UPDATE placement_drives t
SET organization_id = COALESCE(
    (SELECT u.organization_id FROM users u WHERE u.email = t.created_by LIMIT 1),
    1)
WHERE t.organization_id IS NULL;

-- progress (has a direct user_id column via the ManyToOne user_id FK)
UPDATE progress t
SET organization_id = COALESCE(
    (SELECT u.organization_id FROM users u WHERE u.id = t.user_id LIMIT 1),
    (SELECT u.organization_id FROM users u WHERE u.email = t.created_by LIMIT 1),
    1)
WHERE t.organization_id IS NULL;

-- questions (has a direct user_id column)
UPDATE questions t
SET organization_id = COALESCE(
    (SELECT u.organization_id FROM users u WHERE u.id = t.user_id LIMIT 1),
    (SELECT u.organization_id FROM users u WHERE u.email = t.created_by LIMIT 1),
    1)
WHERE t.organization_id IS NULL;

-- student_placements (has a direct user_id FK)
UPDATE student_placements t
SET organization_id = COALESCE(
    (SELECT u.organization_id FROM users u WHERE u.id = t.user_id LIMIT 1),
    (SELECT u.organization_id FROM users u WHERE u.email = t.created_by LIMIT 1),
    1)
WHERE t.organization_id IS NULL;

-- subscriptions (has a direct user_id FK)
UPDATE subscriptions t
SET organization_id = COALESCE(
    (SELECT u.organization_id FROM users u WHERE u.id = t.user_id LIMIT 1),
    (SELECT u.organization_id FROM users u WHERE u.email = t.created_by LIMIT 1),
    1)
WHERE t.organization_id IS NULL;
