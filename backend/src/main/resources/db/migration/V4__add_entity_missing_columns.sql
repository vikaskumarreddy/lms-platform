-- Axisora Forge Academy LMS - V4: Add missing columns to match entity definitions
-- Ensures Hibernate schema-validation (ddl-auto: validate) passes for all mapped entities.

-- ============================================================
-- 1. Users table - entity expects name/username/role/is_active/is_email_verified/last_login
-- ============================================================
ALTER TABLE users ADD COLUMN IF NOT EXISTS name VARCHAR(255) NOT NULL DEFAULT '';
ALTER TABLE users ADD COLUMN IF NOT EXISTS username VARCHAR(255);
ALTER TABLE users ADD COLUMN IF NOT EXISTS role VARCHAR(50);
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_email_verified BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS last_login TIMESTAMP;

-- Entity maps username with unique=true
ALTER TABLE users DROP CONSTRAINT IF EXISTS uk_users_username;
ALTER TABLE users ADD CONSTRAINT uk_users_username UNIQUE (username);

-- ============================================================
-- 2. Courses table - entity expects is_published and instructor_id
-- ============================================================
ALTER TABLE courses ADD COLUMN IF NOT EXISTS is_published BOOLEAN DEFAULT FALSE;
ALTER TABLE courses ADD COLUMN IF NOT EXISTS instructor_id BIGINT REFERENCES users(id);

-- ============================================================
-- 3. Lessons table - entity expects content and video_url
-- ============================================================
ALTER TABLE lessons ADD COLUMN IF NOT EXISTS content TEXT;
ALTER TABLE lessons ADD COLUMN IF NOT EXISTS video_url TEXT;

-- ============================================================
-- 4. Enrollments table - entity expects progress_percentage
-- ============================================================
ALTER TABLE enrollments ADD COLUMN IF NOT EXISTS progress_percentage INTEGER DEFAULT 0;

-- ============================================================
-- 5. Feedback table - entity expects course_id and comment (singular)
-- ============================================================
ALTER TABLE feedback ADD COLUMN IF NOT EXISTS course_id BIGINT REFERENCES courses(id);
ALTER TABLE feedback ADD COLUMN IF NOT EXISTS comment TEXT;

-- ============================================================
-- 6. Comments table - entity expects course_id and parent_id
-- ============================================================
ALTER TABLE comments ADD COLUMN IF NOT EXISTS course_id BIGINT REFERENCES courses(id);
ALTER TABLE comments ADD COLUMN IF NOT EXISTS parent_id BIGINT REFERENCES comments(id);

-- ============================================================
-- 7. Events table - events reference batches
-- ============================================================
ALTER TABLE events ADD COLUMN IF NOT EXISTS batch_id BIGINT REFERENCES batches(id);