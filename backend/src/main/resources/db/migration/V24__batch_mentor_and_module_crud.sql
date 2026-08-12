-- Batches previously had no faculty/mentor link at all (Courses link an
-- instructor, but Batches didn't link any faculty member), which made it
-- impossible to see "who mentors this batch" from the admin portal.
ALTER TABLE batches ADD COLUMN IF NOT EXISTS mentor_id BIGINT REFERENCES users(id);

CREATE INDEX IF NOT EXISTS idx_batches_mentor ON batches(mentor_id);
