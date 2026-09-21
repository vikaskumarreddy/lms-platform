ALTER TABLE notes ADD COLUMN IF NOT EXISTS topic_id BIGINT;
CREATE INDEX IF NOT EXISTS idx_notes_topic ON notes(topic_id);
