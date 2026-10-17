-- V75__add_lesson_notes_type.sql
-- Adds notes_type field to lessons table ('PDF' or 'HTML', default 'PDF')

ALTER TABLE lessons ADD COLUMN IF NOT EXISTS notes_type VARCHAR(10) DEFAULT 'PDF';

UPDATE lessons SET notes_type = 'PDF' WHERE notes_type IS NULL;
