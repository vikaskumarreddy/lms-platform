-- Axisora Forge Academy LMS - V16: Add link column to assignments and exams
-- Entity Assignment/Exam map a `link` (String) field used for "View Details".
ALTER TABLE assignments ADD COLUMN IF NOT EXISTS link VARCHAR(512);
ALTER TABLE exams ADD COLUMN IF NOT EXISTS link VARCHAR(512);