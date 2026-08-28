-- Supports FILL_IN_BLANK/CODING question types: a typed text answer instead of
-- option selection. is_correct becomes nullable because CODING responses are not
-- auto-gradable to a boolean ("not auto-graded" is stored as NULL, not a lossy false).
ALTER TABLE assessment_questions ADD COLUMN answer_text TEXT NULL;
ALTER TABLE assessment_responses ADD COLUMN answer_text TEXT NULL;
ALTER TABLE assessment_responses ALTER COLUMN is_correct DROP NOT NULL;
