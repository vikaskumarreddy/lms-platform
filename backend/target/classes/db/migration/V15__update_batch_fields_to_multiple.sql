-- Update assignments table to support multiple batches
-- These columns were originally added by V14__update_batch_fields_to_multiple.sql
-- This V15 is a re-creation for databases where V14 was applied with different content/checksum
ALTER TABLE assignments ADD COLUMN IF NOT EXISTS batch_ids VARCHAR(500);

-- Migrate existing batch_id data to batch_ids format (safe if batch_id no longer exists)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'assignments' AND column_name = 'batch_id') THEN
        UPDATE assignments SET batch_ids = batch_id::TEXT WHERE batch_id IS NOT NULL AND batch_ids IS NULL;
    END IF;
END $$;

-- Drop the old batch_id column if it still exists
ALTER TABLE assignments DROP COLUMN IF EXISTS batch_id;

-- Create index for the new column
CREATE INDEX IF NOT EXISTS idx_assignments_batch_ids ON assignments(batch_ids);

-- Update exams table to support multiple batches
ALTER TABLE exams ADD COLUMN IF NOT EXISTS batch_ids VARCHAR(500);

-- Migrate existing batch_id data to batch_ids format (safe if batch_id no longer exists)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'exams' AND column_name = 'batch_id') THEN
        UPDATE exams SET batch_ids = batch_id::TEXT WHERE batch_id IS NOT NULL AND batch_ids IS NULL;
    END IF;
END $$;

-- Drop the old batch_id column if it still exists
ALTER TABLE exams DROP COLUMN IF EXISTS batch_id;

-- Create index for the new column
CREATE INDEX IF NOT EXISTS idx_exams_batch_ids ON exams(batch_ids);
