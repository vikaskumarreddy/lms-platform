-- Axisora Forge Academy LMS - V2: Mobile Content & Admin Control Enhancements
-- These changes enable the admin UI to control Android app content, subscriptions, and notifications.

-- ============================================================
-- 1. Mobile Content table - controls Android app home screen
-- ============================================================
CREATE TABLE IF NOT EXISTS mobile_content (
    id BIGSERIAL PRIMARY KEY,
    section VARCHAR(100) NOT NULL,
    item_type VARCHAR(50),
    title VARCHAR(255) NOT NULL,
    subtitle TEXT,
    description TEXT,
    value_field VARCHAR(255),
    link_url TEXT,
    icon VARCHAR(50),
    color VARCHAR(20),
    order_index INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    metadata TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(255),
    updated_by VARCHAR(255),
    version BIGINT DEFAULT 0,
    CONSTRAINT uk_mobile_content_section_type_title UNIQUE (section, item_type, title)
);

CREATE INDEX IF NOT EXISTS idx_mobile_content_section ON mobile_content(section);
CREATE INDEX IF NOT EXISTS idx_mobile_content_active ON mobile_content(is_active);
CREATE INDEX IF NOT EXISTS idx_mobile_content_order ON mobile_content(section, order_index);

-- ============================================================
-- 2. Enhance notifications for targeting/broadcast
-- ============================================================
ALTER TABLE notifications
    ADD COLUMN IF NOT EXISTS target_type VARCHAR(50) DEFAULT 'ALL',
    ADD COLUMN IF NOT EXISTS target_id BIGINT,
    ADD COLUMN IF NOT EXISTS broadcast BOOLEAN DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_notifications_target ON notifications(target_type, target_id);

-- ============================================================
-- 3. Enhance subscription_plans with display fields
-- ============================================================
ALTER TABLE subscription_plans
    ADD COLUMN IF NOT EXISTS color VARCHAR(20) DEFAULT '#0F172A',
    ADD COLUMN IF NOT EXISTS period VARCHAR(50) DEFAULT '/month',
    ADD COLUMN IF NOT EXISTS is_popular BOOLEAN DEFAULT FALSE;

-- ============================================================
-- 4. Enhance subscriptions with payment reference
-- ============================================================
ALTER TABLE subscriptions
    ADD COLUMN IF NOT EXISTS payment_id BIGINT REFERENCES payments(id);

-- ============================================================
-- 5. Insert default mobile content for home screen
-- ============================================================
INSERT INTO mobile_content (section, item_type, title, subtitle, description, value_field, link_url, icon, color, order_index, is_active, metadata) VALUES
('home_banner', 'banner_title', 'Welcome back, Student!', 'Continue your learning journey', NULL, NULL, '/courses', NULL, '#0F172A', 0, TRUE, '{}'),
('home_banner', 'banner_button', 'Resume Learning', NULL, NULL, NULL, '/courses', NULL, '#EAB308', 1, TRUE, '{}'),
('quick_stats', 'stat', 'Attendance', 'This month', '85%', NULL, NULL, '✅', '#22C55E', 0, TRUE, '{}'),
('quick_stats', 'stat', 'Progress', 'Course progress', '65%', NULL, NULL, '📈', '#EAB308', 1, TRUE, '{}'),
('quick_stats', 'stat', 'Performance', 'Overall', '78%', NULL, NULL, '⭐', '#3B82F6', 2, TRUE, '{}'),
('quick_stats', 'stat', 'Streak', 'Current streak', '5 days', NULL, NULL, '🔥', '#F97316', 3, TRUE, '{}'),
('quick_links', 'link', 'Courses', NULL, NULL, NULL, '/courses', '📚', '#0F172A', 0, TRUE, '{}'),
('quick_links', 'link', 'Calendar', NULL, NULL, NULL, '/calendar', '📅', '#0F172A', 1, TRUE, '{}'),
('quick_links', 'link', 'Placements', NULL, NULL, NULL, '/placement-drives', '💼', '#0F172A', 2, TRUE, '{}'),
('quick_links', 'link', 'Assignments', NULL, NULL, NULL, '/assignments', '📝', '#0F172A', 3, TRUE, '{}'),
('quick_links', 'link', 'Achievements', NULL, NULL, NULL, '/achievements', '🏆', '#0F172A', 4, TRUE, '{}'),
('quick_links', 'link', 'Q&A', NULL, NULL, NULL, '/qa', '💬', '#0F172A', 5, TRUE, '{}')
ON CONFLICT (section, item_type, title) DO NOTHING;
