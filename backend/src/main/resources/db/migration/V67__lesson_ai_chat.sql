-- =====================================================================
-- V67: Lesson AI Chatbot with PDF Context & Configurable Question Limits
-- =====================================================================

-- 1) Configurable Lesson AI Chat Question Limit (default 100 per student/lesson)
ALTER TABLE org_ai_config ADD COLUMN IF NOT EXISTS lesson_ai_question_limit INT NOT NULL DEFAULT 100;

-- 2) Persisted student chat history for lesson AI tutor
CREATE TABLE IF NOT EXISTS lesson_ai_chat_messages (
    id              BIGSERIAL PRIMARY KEY,
    organization_id BIGINT,
    user_id         BIGINT NOT NULL,
    lesson_id       BIGINT NOT NULL,
    role            VARCHAR(20) NOT NULL, -- 'user' or 'assistant'
    content         TEXT NOT NULL,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP,
    created_by      VARCHAR(100),
    updated_by      VARCHAR(100),
    version         BIGINT DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_lesson_ai_chat_user_lesson ON lesson_ai_chat_messages(user_id, lesson_id, created_at);
CREATE INDEX IF NOT EXISTS idx_lesson_ai_chat_org ON lesson_ai_chat_messages(organization_id);
