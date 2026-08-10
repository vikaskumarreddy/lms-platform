-- Axisora Forge Academy LMS - V8: Add subscription plan fields to students and placement drives

-- Add plan_id to users table to link students with subscription plans
ALTER TABLE users ADD COLUMN IF NOT EXISTS plan_id BIGINT REFERENCES subscription_plans(id);

-- Add plan_id to placement_drives table to link drives with subscription plans
ALTER TABLE placement_drives ADD COLUMN IF NOT EXISTS plan_id BIGINT REFERENCES subscription_plans(id);