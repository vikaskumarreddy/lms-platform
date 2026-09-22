-- =====================================================================
-- V66: AI Intelligence, Org AI Config & Daily AI Challenges
-- =====================================================================

-- 1) Org-level AI Model & API Key Configuration
CREATE TABLE IF NOT EXISTS org_ai_config (
    id                    BIGSERIAL PRIMARY KEY,
    organization_id       BIGINT,
    model_name            VARCHAR(50) NOT NULL DEFAULT 'gemini-1.5-flash',
    api_key               TEXT,
    enabled               BOOLEAN NOT NULL DEFAULT TRUE,
    daily_question_limit  INT NOT NULL DEFAULT 10,
    daily_challenge_limit INT NOT NULL DEFAULT 1,
    created_at            TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMP,
    created_by            VARCHAR(100),
    updated_by            VARCHAR(100),
    version               BIGINT DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_org_ai_config_org ON org_ai_config(organization_id);

-- 2) Daily AI Challenge Attempts (1/day limit & Leaderboard point tracking)
CREATE TABLE IF NOT EXISTS daily_challenge_attempts (
    id               BIGSERIAL PRIMARY KEY,
    organization_id  BIGINT,
    user_id          BIGINT NOT NULL,
    lesson_id        BIGINT,
    score            INT NOT NULL DEFAULT 0,
    total_questions  INT NOT NULL DEFAULT 5,
    points_awarded   DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    completed_at     TIMESTAMP NOT NULL DEFAULT NOW(),
    details_json     TEXT,
    created_at       TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMP,
    created_by       VARCHAR(100),
    updated_by       VARCHAR(100),
    version          BIGINT DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_challenge_attempts_user ON daily_challenge_attempts(user_id, completed_at);
CREATE INDEX IF NOT EXISTS idx_challenge_attempts_org ON daily_challenge_attempts(organization_id);

-- 3) Question escalation and AI flags
ALTER TABLE questions ADD COLUMN IF NOT EXISTS is_escalated BOOLEAN DEFAULT FALSE;
ALTER TABLE questions ADD COLUMN IF NOT EXISTS is_ai_answered BOOLEAN DEFAULT FALSE;

-- 4) Answer AI-generated flag
ALTER TABLE answers ADD COLUMN IF NOT EXISTS is_ai_generated BOOLEAN DEFAULT FALSE;
