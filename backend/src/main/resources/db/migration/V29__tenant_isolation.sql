-- =====================================================================
-- V29: Tenant isolation – add organization_id to tenant tables and backfill
-- =====================================================================

-- =====================================================================
-- V29: Tenant isolation – add organization_id column to tenant tables
-- (first half: ALTER TABLE statements)
-- =====================================================================

ALTER TABLE answers ADD COLUMN IF NOT EXISTS organization_id BIGINT;
ALTER TABLE assignments ADD COLUMN IF NOT EXISTS organization_id BIGINT;
ALTER TABLE assignment_submissions ADD COLUMN IF NOT EXISTS organization_id BIGINT;
ALTER TABLE attendance ADD COLUMN IF NOT EXISTS organization_id BIGINT;
ALTER TABLE bookmarks ADD COLUMN IF NOT EXISTS organization_id BIGINT;
ALTER TABLE comments ADD COLUMN IF NOT EXISTS organization_id BIGINT;
ALTER TABLE courses ADD COLUMN IF NOT EXISTS organization_id BIGINT;
ALTER TABLE enrollments ADD COLUMN IF NOT EXISTS organization_id BIGINT;
ALTER TABLE events ADD COLUMN IF NOT EXISTS organization_id BIGINT;
ALTER TABLE exams ADD COLUMN IF NOT EXISTS organization_id BIGINT;
ALTER TABLE exam_submissions ADD COLUMN IF NOT EXISTS organization_id BIGINT;
ALTER TABLE feedback ADD COLUMN IF NOT EXISTS organization_id BIGINT;
ALTER TABLE lessons ADD COLUMN IF NOT EXISTS organization_id BIGINT;
ALTER TABLE modules ADD COLUMN IF NOT EXISTS organization_id BIGINT;

-- =====================================================================
-- V29: Tenant isolation – backfill organization_id from created_by
-- (second half: UPDATE statements)
-- =====================================================================

-- answers
UPDATE answers a
SET organization_id = COALESCE(
    (SELECT u.organization_id
     FROM users u
     WHERE u.email = a.created_by
     LIMIT 1),
    1)
WHERE a.organization_id IS NULL;

-- assignments
UPDATE assignments al
SET organization_id = COALESCE(
    (SELECT u.organization_id
     FROM users u
     WHERE u.email = al.created_by
     LIMIT 1),
    1)
WHERE al.organization_id IS NULL;

-- assignment_submissions
UPDATE assignment_submissions al
SET organization_id = COALESCE(
    (SELECT u.organization_id
     FROM users u
     WHERE u.email = al.created_by
     LIMIT 1),
    1)
WHERE al.organization_id IS NULL;

-- attendance
UPDATE attendance al
SET organization_id = COALESCE(
    (SELECT u.organization_id
     FROM users u
     WHERE u.email = al.created_by
     LIMIT 1),
    1)
WHERE al.organization_id IS NULL;

-- bookmarks
UPDATE bookmarks b
SET organization_id = COALESCE(
    (SELECT u.organization_id
     FROM users u
     WHERE u.email = b.created_by
     LIMIT 1),
    1)
WHERE b.organization_id IS NULL;

-- comments
UPDATE comments c
SET organization_id = COALESCE(
    (SELECT u.organization_id
     FROM users u
     WHERE u.email = c.created_by
     LIMIT 1),
    1)
WHERE c.organization_id IS NULL;

-- courses
UPDATE courses co
SET organization_id = COALESCE(
    (SELECT u.organization_id
     FROM users u
     WHERE u.email = co.created_by
     LIMIT 1),
    1)
WHERE co.organization_id IS NULL;

-- enrollments
UPDATE enrollments en
SET organization_id = COALESCE(
    (SELECT u.organization_id
     FROM users u
     WHERE u.email = en.created_by
     LIMIT 1),
    1)
WHERE en.organization_id IS NULL;

-- events
UPDATE events ev
SET organization_id = COALESCE(
    (SELECT u.organization_id
     FROM users u
     WHERE u.email = ev.created_by
     LIMIT 1),
    1)
WHERE ev.organization_id IS NULL;

-- exams
UPDATE exams ex
SET organization_id = COALESCE(
    (SELECT u.organization_id
     FROM users u
     WHERE u.email = ex.created_by
     LIMIT 1),
    1)
WHERE ex.organization_id IS NULL;

-- exam_submissions
UPDATE exam_submissions es
SET organization_id = COALESCE(
    (SELECT u.organization_id
     FROM users u
     WHERE u.email = es.created_by
     LIMIT 1),
    1)
WHERE es.organization_id IS NULL;

-- feedback
UPDATE feedback f
SET organization_id = COALESCE(
    (SELECT u.organization_id
     FROM users u
     WHERE u.email = f.created_by
     LIMIT 1),
    1)
WHERE f.organization_id IS NULL;

-- lessons
UPDATE lessons l
SET organization_id = COALESCE(
    (SELECT u.organization_id
     FROM users u
     WHERE u.email = l.created_by
     LIMIT 1),
    1)
WHERE l.organization_id IS NULL;

-- modules
UPDATE modules m
SET organization_id = COALESCE(
    (SELECT u.organization_id
     FROM users u
     WHERE u.email = m.created_by
     LIMIT 1),
    1)
WHERE m.organization_id IS NULL;
