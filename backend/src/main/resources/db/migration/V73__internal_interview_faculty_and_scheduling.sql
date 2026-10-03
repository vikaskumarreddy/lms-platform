-- V73: Internal placement drive faculty assignment and interview scheduling enhancements

-- 1) Allow internal placement drives to have an assigned faculty/interviewer
ALTER TABLE placement_drives ADD COLUMN IF NOT EXISTS assigned_faculty_id BIGINT REFERENCES users(id);
ALTER TABLE placement_drives ADD COLUMN IF NOT EXISTS faculty_name VARCHAR(255);
ALTER TABLE placement_drives ADD COLUMN IF NOT EXISTS faculty_email VARCHAR(255);

-- 2) Schedulable interview slots can carry an assigned faculty and room code
ALTER TABLE interview_slots ADD COLUMN IF NOT EXISTS faculty_id BIGINT REFERENCES users(id);
ALTER TABLE interview_slots ADD COLUMN IF NOT EXISTS faculty_name VARCHAR(255);
ALTER TABLE interview_slots ADD COLUMN IF NOT EXISTS faculty_email VARCHAR(255);
ALTER TABLE interview_slots ADD COLUMN IF NOT EXISTS room_code VARCHAR(64);

-- 3) Index for querying slots and sessions by faculty
CREATE INDEX IF NOT EXISTS idx_interview_slots_faculty ON interview_slots(faculty_id);
CREATE INDEX IF NOT EXISTS idx_interview_sessions_interviewer ON interview_sessions(interviewer_id);
