-- Placement drive eligibility criteria (minimum thresholds in percent).
-- A NULL value means that specific rule is not enforced for the drive.
ALTER TABLE placement_drives ADD COLUMN IF NOT EXISTS min_attendance_percent DOUBLE PRECISION;
ALTER TABLE placement_drives ADD COLUMN IF NOT EXISTS min_course_completion_percent DOUBLE PRECISION;
ALTER TABLE placement_drives ADD COLUMN IF NOT EXISTS min_assignment_avg_percent DOUBLE PRECISION;
ALTER TABLE placement_drives ADD COLUMN IF NOT EXISTS min_exam_avg_percent DOUBLE PRECISION;
