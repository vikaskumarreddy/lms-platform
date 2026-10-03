-- V74: Add interviewer_email column to interview_sessions table
ALTER TABLE interview_sessions ADD COLUMN IF NOT EXISTS interviewer_email VARCHAR(255);
