-- V18: Attendance tracking table + placement application status

CREATE TABLE IF NOT EXISTS attendance (
    id BIGSERIAL PRIMARY KEY,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(255),
    updated_by VARCHAR(255),
    version BIGINT DEFAULT 0,
    deleted_at TIMESTAMP,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    event_id BIGINT NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    present BOOLEAN NOT NULL DEFAULT FALSE,
    remarks VARCHAR(500),
    UNIQUE (user_id, event_id)
);

CREATE INDEX IF NOT EXISTS idx_attendance_user_id ON attendance(user_id);
CREATE INDEX IF NOT EXISTS idx_attendance_event_id ON attendance(event_id);

-- Placement application status for student_placements (Open / Applied / Selected)
ALTER TABLE student_placements ADD COLUMN IF NOT EXISTS status VARCHAR(20) NOT NULL DEFAULT 'APPLIED';
ALTER TABLE student_placements ADD COLUMN IF NOT EXISTS drive_id BIGINT REFERENCES placement_drives(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_student_placements_drive_id ON student_placements(drive_id);
