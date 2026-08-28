-- =====================================================================
-- V42: In-app assessment papers
--
-- Assignments and exams can now be delivered one of two ways:
--   WEB    - the existing behaviour: a `link` is published and the mobile
--            app opens it in the embedded browser.
--   IN_APP - the institute authors a question paper here, the student
--            answers it natively in the app, and it is graded automatically.
--
-- Existing rows keep the old behaviour (default 'WEB').
-- =====================================================================

ALTER TABLE assignments ADD COLUMN IF NOT EXISTS delivery_mode VARCHAR(20) NOT NULL DEFAULT 'WEB';
ALTER TABLE exams       ADD COLUMN IF NOT EXISTS delivery_mode VARCHAR(20) NOT NULL DEFAULT 'WEB';

-- ---------------------------------------------------------------------
-- Questions
--
-- assessment_type + assessment_id is a polymorphic pointer at either an
-- assignment or an exam. A real FK is not possible across two parent
-- tables, so orphan rows are cleaned up by the delete endpoints instead.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS assessment_questions (
    id              BIGSERIAL PRIMARY KEY,
    assessment_type VARCHAR(20) NOT NULL,
    assessment_id   BIGINT      NOT NULL,
    question_text   TEXT        NOT NULL,
    -- SINGLE_CHOICE renders radio buttons in the app, MULTIPLE_ANSWER renders
    -- checkboxes. This is what drives the widget choice on the student side.
    question_type   VARCHAR(30) NOT NULL DEFAULT 'SINGLE_CHOICE',
    explanation     TEXT,
    marks           INTEGER     NOT NULL DEFAULT 1,
    display_order   INTEGER     NOT NULL DEFAULT 0,
    organization_id BIGINT,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by      VARCHAR(255),
    updated_by      VARCHAR(255),
    version         BIGINT DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_assessment_questions_parent
    ON assessment_questions (assessment_type, assessment_id, display_order);

-- ---------------------------------------------------------------------
-- Options
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS assessment_question_options (
    id              BIGSERIAL PRIMARY KEY,
    question_id     BIGINT      NOT NULL REFERENCES assessment_questions(id) ON DELETE CASCADE,
    option_text     TEXT        NOT NULL,
    is_correct      BOOLEAN     NOT NULL DEFAULT FALSE,
    display_order   INTEGER     NOT NULL DEFAULT 0,
    organization_id BIGINT,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by      VARCHAR(255),
    updated_by      VARCHAR(255),
    version         BIGINT DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_assessment_options_question
    ON assessment_question_options (question_id, display_order);

-- ---------------------------------------------------------------------
-- Responses
--
-- One row per student per question. Storing this relationally (rather than
-- as a JSON blob on the submission) is what lets a mentor open any single
-- student and see exactly which options they picked, and lets us report on
-- "which question did the batch get wrong most often".
--
-- selected_option_ids is a comma-separated id list read through
-- LongListConverter, matching the existing batch_ids convention.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS assessment_responses (
    id                  BIGSERIAL PRIMARY KEY,
    assessment_type     VARCHAR(20) NOT NULL,
    assessment_id       BIGINT      NOT NULL,
    submission_id       BIGINT,
    user_id             BIGINT      NOT NULL,
    question_id         BIGINT      NOT NULL,
    selected_option_ids VARCHAR(512),
    is_correct          BOOLEAN     NOT NULL DEFAULT FALSE,
    marks_awarded       INTEGER     NOT NULL DEFAULT 0,
    organization_id     BIGINT,
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by          VARCHAR(255),
    updated_by          VARCHAR(255),
    version             BIGINT DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_assessment_responses_parent
    ON assessment_responses (assessment_type, assessment_id);
CREATE INDEX IF NOT EXISTS idx_assessment_responses_student
    ON assessment_responses (assessment_type, assessment_id, user_id);
