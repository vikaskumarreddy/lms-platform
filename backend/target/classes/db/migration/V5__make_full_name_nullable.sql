-- Axisora Forge Academy LMS - V5: Make full_name nullable
-- The User entity uses "name" column (added in V4), not "full_name".
-- The original "full_name" column from V1 has NOT NULL constraint which causes
-- insert failures when the entity doesn't populate it.
ALTER TABLE users ALTER COLUMN full_name DROP NOT NULL;