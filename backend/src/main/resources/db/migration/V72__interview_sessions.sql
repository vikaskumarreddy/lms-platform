-- V72: 1-on-1 Realtime Interview Sessions with 100ms and live coding

CREATE TABLE IF NOT EXISTS interview_sessions (
    id BIGSERIAL PRIMARY KEY,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    created_by VARCHAR(255),
    updated_by VARCHAR(255),
    version BIGINT DEFAULT 0,
    organization_id BIGINT,

    room_code VARCHAR(64) NOT NULL UNIQUE,
    title VARCHAR(255) NOT NULL DEFAULT '1-on-1 Technical Interview',
    slot_id BIGINT,
    drive_id BIGINT,
    candidate_id BIGINT,
    candidate_name VARCHAR(255),
    candidate_email VARCHAR(255),
    interviewer_id BIGINT,
    interviewer_name VARCHAR(255),
    status VARCHAR(32) NOT NULL DEFAULT 'SCHEDULED',
    scheduled_at TIMESTAMP,
    started_at TIMESTAMP,
    ended_at TIMESTAMP,

    hms_room_id VARCHAR(255),
    hms_room_code VARCHAR(255),
    hms_meeting_url VARCHAR(1024),

    problem_id BIGINT,
    problem_title VARCHAR(255),
    problem_difficulty VARCHAR(32),
    problem_description TEXT,
    code_language VARCHAR(32) DEFAULT 'java',
    submitted_code TEXT,

    problem_solving_score INT,
    technical_competency_score INT,
    code_quality_score INT,
    communication_score INT,
    hiring_decision VARCHAR(32),
    interviewer_notes TEXT,
    candidate_notes TEXT
);

CREATE INDEX IF NOT EXISTS idx_interview_room_code ON interview_sessions(room_code);
CREATE INDEX IF NOT EXISTS idx_interview_candidate ON interview_sessions(candidate_id);
CREATE INDEX IF NOT EXISTS idx_interview_slot ON interview_sessions(slot_id);
CREATE INDEX IF NOT EXISTS idx_interview_org ON interview_sessions(organization_id);
