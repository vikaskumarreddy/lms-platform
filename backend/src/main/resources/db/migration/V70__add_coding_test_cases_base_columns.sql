-- V70__add_coding_test_cases_base_columns.sql
-- Add BaseEntity audit and tenant columns to coding_test_cases table

ALTER TABLE coding_test_cases ADD COLUMN IF NOT EXISTS organization_id BIGINT;
ALTER TABLE coding_test_cases ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE coding_test_cases ADD COLUMN IF NOT EXISTS created_by VARCHAR(255);
ALTER TABLE coding_test_cases ADD COLUMN IF NOT EXISTS updated_by VARCHAR(255);
ALTER TABLE coding_test_cases ADD COLUMN IF NOT EXISTS version BIGINT DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_coding_test_cases_org
    ON coding_test_cases (organization_id);

-- Backfill organization_id from assessment_questions for any existing test cases
UPDATE coding_test_cases ctc
SET organization_id = aq.organization_id
FROM assessment_questions aq
WHERE ctc.question_id = aq.id AND ctc.organization_id IS NULL;
