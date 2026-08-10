-- Axisora Forge Academy LMS - V9: Batches, batch_id on users/events, plan_id on events

-- Create batches table
CREATE TABLE IF NOT EXISTS batches (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    plan_id BIGINT REFERENCES subscription_plans(id),
    start_date TIMESTAMP,
    end_date TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    max_students INTEGER,
    schedule VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    version BIGINT DEFAULT 0
);

-- Add missing columns to an existing batches table (idempotent).
-- This handles the case where the table already existed (e.g. from a partial
-- migration run) and was skipped by the CREATE TABLE IF NOT EXISTS above.
ALTER TABLE batches ADD COLUMN IF NOT EXISTS name VARCHAR(255);
ALTER TABLE batches ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE batches ADD COLUMN IF NOT EXISTS plan_id BIGINT REFERENCES subscription_plans(id);
ALTER TABLE batches ADD COLUMN IF NOT EXISTS start_date TIMESTAMP;
ALTER TABLE batches ADD COLUMN IF NOT EXISTS end_date TIMESTAMP;
ALTER TABLE batches ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;
ALTER TABLE batches ADD COLUMN IF NOT EXISTS max_students INTEGER;
ALTER TABLE batches ADD COLUMN IF NOT EXISTS schedule VARCHAR(255);
ALTER TABLE batches ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE batches ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE batches ADD COLUMN IF NOT EXISTS version BIGINT DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_batches_active ON batches(is_active);
CREATE INDEX IF NOT EXISTS idx_batches_plan ON batches(plan_id);

-- Add batch_id to users (students belong to a batch)
ALTER TABLE users ADD COLUMN IF NOT EXISTS batch_id BIGINT REFERENCES batches(id);

-- Add batch_id and plan_id to events (calendar events linked to batch and subscription)
ALTER TABLE events ADD COLUMN IF NOT EXISTS batch_id BIGINT REFERENCES batches(id);
ALTER TABLE events ADD COLUMN IF NOT EXISTS plan_id BIGINT REFERENCES subscription_plans(id);

-- Add target_type support for SUBSCRIPTION in notifications (target_type column already exists from V2)
-- The notifications table already has target_type, target_id, broadcast columns from V2 migration
-- We just need to ensure the SUBSCRIPTION target type is supported via the controller logic
