-- V71: Add coding_title to assessment_questions table
ALTER TABLE assessment_questions ADD COLUMN IF NOT EXISTS coding_title VARCHAR(255);
