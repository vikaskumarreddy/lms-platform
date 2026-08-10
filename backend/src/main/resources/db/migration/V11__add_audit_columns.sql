-- Axisora Forge Academy LMS - V11: Add missing BaseEntity audit columns
-- The tables created in V10 (student_placements, assignments, assignment_submissions,
-- exams, exam_submissions) missed the created_by/updated_by/version columns that
-- all entities inherit from BaseEntity. This adds them to satisfy Hibernate schema
-- validation (ddl-auto: validate).

ALTER TABLE student_placements ADD COLUMN IF NOT EXISTS created_by VARCHAR(255);
ALTER TABLE student_placements ADD COLUMN IF NOT EXISTS updated_by VARCHAR(255);
ALTER TABLE student_placements ADD COLUMN IF NOT EXISTS version BIGINT DEFAULT 0;

ALTER TABLE assignments ADD COLUMN IF NOT EXISTS created_by VARCHAR(255);
ALTER TABLE assignments ADD COLUMN IF NOT EXISTS updated_by VARCHAR(255);
ALTER TABLE assignments ADD COLUMN IF NOT EXISTS version BIGINT DEFAULT 0;

ALTER TABLE assignment_submissions ADD COLUMN IF NOT EXISTS created_by VARCHAR(255);
ALTER TABLE assignment_submissions ADD COLUMN IF NOT EXISTS updated_by VARCHAR(255);
ALTER TABLE assignment_submissions ADD COLUMN IF NOT EXISTS version BIGINT DEFAULT 0;

ALTER TABLE exams ADD COLUMN IF NOT EXISTS created_by VARCHAR(255);
ALTER TABLE exams ADD COLUMN IF NOT EXISTS updated_by VARCHAR(255);
ALTER TABLE exams ADD COLUMN IF NOT EXISTS version BIGINT DEFAULT 0;

ALTER TABLE exam_submissions ADD COLUMN IF NOT EXISTS created_by VARCHAR(255);
ALTER TABLE exam_submissions ADD COLUMN IF NOT EXISTS updated_by VARCHAR(255);
ALTER TABLE exam_submissions ADD COLUMN IF NOT EXISTS version BIGINT DEFAULT 0;