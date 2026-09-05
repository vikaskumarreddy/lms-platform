-- Media & Files library: videos and files (PDF/image) uploaded through the
-- admin portal "Media & Files" hub. Reused by Courses (lesson video/PDF) and
-- Company Questions (self-hosted PDF). Bytes live on disk (compressed), this
-- table holds metadata only — mirrors the pdf_documents/pdf_notes pattern.
CREATE TABLE IF NOT EXISTS media_items (
    id BIGSERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    media_type VARCHAR(20) NOT NULL, -- 'video' or 'file'
    mime_type VARCHAR(100),
    file_name VARCHAR(255),
    original_size BIGINT,
    stored_size BIGINT,
    duration_seconds INT,
    width INT,
    height INT,
    created_by_user_id BIGINT,
    organization_id BIGINT,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    created_by VARCHAR(255),
    updated_by VARCHAR(255),
    version BIGINT DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_media_items_org ON media_items(organization_id);
CREATE INDEX IF NOT EXISTS idx_media_items_type ON media_items(media_type);

-- Lessons: self-hosted video alongside the existing self-hosted PDF fields.
ALTER TABLE lessons ADD COLUMN IF NOT EXISTS video_source VARCHAR(10);
ALTER TABLE lessons ADD COLUMN IF NOT EXISTS video_id BIGINT;

-- Company kits and lessons already have pdf_source/pdf_note_id (V56); those
-- columns are reused as-is — pdf_note_id now stores a media_items.id instead
-- of a pdf_notes.id, since the "Create PDF" generator was replaced by direct
-- file uploads. No column rename needed, existing rows referencing old
-- pdf_notes ids simply won't resolve (pdf_notes table itself is left in place
-- and untouched by this migration).
