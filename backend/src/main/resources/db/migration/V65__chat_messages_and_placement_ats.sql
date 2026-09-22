-- =====================================================================
-- V65: Chat Messages, Placement ATS & Recruiter Portal
-- =====================================================================

-- 1) Chat messages table for batch community channels
CREATE TABLE IF NOT EXISTS chat_messages (
    id              BIGSERIAL PRIMARY KEY,
    organization_id BIGINT,
    batch_id        BIGINT,
    sender_id       BIGINT NOT NULL,
    sender_name     VARCHAR(255) NOT NULL,
    sender_role     VARCHAR(50) NOT NULL,
    content         TEXT NOT NULL,
    message_type    VARCHAR(30) NOT NULL DEFAULT 'TEXT', -- TEXT, CODE, ANNOUNCEMENT
    code_language   VARCHAR(50),
    created_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP,
    created_by      VARCHAR(100),
    updated_by      VARCHAR(100),
    version         BIGINT DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_chat_messages_batch ON chat_messages(batch_id, created_at);
CREATE INDEX IF NOT EXISTS idx_chat_messages_org ON chat_messages(organization_id);

-- 2) Placement drive recruiter token for external HR review
ALTER TABLE placement_drives ADD COLUMN IF NOT EXISTS recruiter_token VARCHAR(100);

-- 3) Student placements ATS score, hiring stage, and resume URL
ALTER TABLE student_placements ADD COLUMN IF NOT EXISTS ats_score DOUBLE PRECISION DEFAULT 0.0;
ALTER TABLE student_placements ADD COLUMN IF NOT EXISTS hiring_stage VARCHAR(50) DEFAULT 'APPLIED';
ALTER TABLE student_placements ADD COLUMN IF NOT EXISTS resume_url VARCHAR(1000);
