-- V69__coding_platform_test_cases.sql
-- Realtime coding platform support: test cases, starter code, problem constraints, and auto-grading.

CREATE TABLE IF NOT EXISTS coding_test_cases (
    id BIGSERIAL PRIMARY KEY,
    question_id BIGINT NOT NULL REFERENCES assessment_questions(id) ON DELETE CASCADE,
    input TEXT NOT NULL DEFAULT '',
    expected_output TEXT NOT NULL DEFAULT '',
    is_sample BOOLEAN NOT NULL DEFAULT false,
    explanation TEXT NULL,
    display_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_coding_test_cases_question
    ON coding_test_cases (question_id, display_order);

ALTER TABLE assessment_questions ADD COLUMN IF NOT EXISTS coding_starter_java TEXT NULL;
ALTER TABLE assessment_questions ADD COLUMN IF NOT EXISTS coding_starter_python TEXT NULL;
ALTER TABLE assessment_questions ADD COLUMN IF NOT EXISTS coding_constraints TEXT NULL;
ALTER TABLE assessment_questions ADD COLUMN IF NOT EXISTS coding_input_format TEXT NULL;
ALTER TABLE assessment_questions ADD COLUMN IF NOT EXISTS coding_output_format TEXT NULL;
ALTER TABLE assessment_questions ADD COLUMN IF NOT EXISTS coding_difficulty VARCHAR(20) DEFAULT 'MEDIUM';

ALTER TABLE assessment_responses ADD COLUMN IF NOT EXISTS language VARCHAR(20) NULL;
ALTER TABLE assessment_responses ADD COLUMN IF NOT EXISTS test_cases_passed INT NULL;
ALTER TABLE assessment_responses ADD COLUMN IF NOT EXISTS total_test_cases INT NULL;
ALTER TABLE assessment_responses ADD COLUMN IF NOT EXISTS code_output TEXT NULL;
