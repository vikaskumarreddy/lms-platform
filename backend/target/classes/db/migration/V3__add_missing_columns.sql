-- Add missing columns to match entity definitions
-- Attendance table needs attended_at column
ALTER TABLE attendance ADD COLUMN IF NOT EXISTS attended_at TIMESTAMP;

-- Progress table may need additional columns
ALTER TABLE progress ADD COLUMN IF NOT EXISTS completed_at TIMESTAMP;
ALTER TABLE progress ADD COLUMN IF NOT EXISTS is_completed BOOLEAN DEFAULT FALSE;

-- Bookmark table needs bookmarked_at column  
ALTER TABLE bookmarks ADD COLUMN IF NOT EXISTS bookmarked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;