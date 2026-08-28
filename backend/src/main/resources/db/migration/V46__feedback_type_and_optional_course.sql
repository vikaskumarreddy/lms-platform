-- Feedback can now be general/bug/feature reports not tied to a course.
ALTER TABLE feedback ALTER COLUMN course_id DROP NOT NULL;
ALTER TABLE feedback ADD COLUMN IF NOT EXISTS type VARCHAR(50) DEFAULT 'General';
