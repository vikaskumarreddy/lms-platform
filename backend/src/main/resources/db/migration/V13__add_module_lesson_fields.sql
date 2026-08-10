-- Axisora Forge Academy LMS - V13: Add icon/color/is_locked to modules, heading to lessons
-- These fields power the mobile app course detail & section lessons screens.

-- ============================================================
-- Modules: add icon, color, and is_locked for mobile section cards
-- ============================================================
ALTER TABLE modules ADD COLUMN IF NOT EXISTS icon VARCHAR(50);
ALTER TABLE modules ADD COLUMN IF NOT EXISTS color VARCHAR(20);
ALTER TABLE modules ADD COLUMN IF NOT EXISTS is_locked BOOLEAN DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_modules_course ON modules(course_id);

-- ============================================================
-- Lessons: add heading (display sub-title on lesson player screen)
-- (is_locked, is_mandatory, thumbnail_url, pdf_notes_url already exist from V1)
-- ============================================================
ALTER TABLE lessons ADD COLUMN IF NOT EXISTS heading VARCHAR(255);
