-- Placement drives can now be INTERNAL (institute-run interview process with
-- schedulable slots) or EXTERNAL (company-run, informational only, students
-- just apply via the existing apply link) drives.
ALTER TABLE placement_drives ADD COLUMN IF NOT EXISTS drive_type VARCHAR(20) NOT NULL DEFAULT 'EXTERNAL';

-- Interview slots the admin creates for an INTERNAL placement drive; students
-- book a slot ("Schedule my slot") which the admin can then track/manage.
CREATE TABLE interview_slots (
    id BIGSERIAL PRIMARY KEY,
    drive_id BIGINT NOT NULL REFERENCES placement_drives(id) ON DELETE CASCADE,
    slot_time TIMESTAMP NOT NULL,
    location VARCHAR(255),
    notes VARCHAR(500),
    booked_by_user_id BIGINT REFERENCES users(id),
    booked_at TIMESTAMP,
    status VARCHAR(20) NOT NULL DEFAULT 'AVAILABLE',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    version BIGINT DEFAULT 0,
    created_by VARCHAR(255),
    updated_by VARCHAR(255)
);

CREATE INDEX idx_interview_slots_drive ON interview_slots(drive_id);
CREATE INDEX idx_interview_slots_booked_by ON interview_slots(booked_by_user_id);
