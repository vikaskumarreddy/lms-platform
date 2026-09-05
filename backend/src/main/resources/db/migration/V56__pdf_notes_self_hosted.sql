-- Faculty-authored PDF notes ("Create PDF" feature). The rendered PDF is stored
-- gzipped on disk under uploads/pdf-notes/ and served decompressed through
-- /api/pdf-notes/{id}/file, so PDFBox's internal stream compression plus gzip
-- keeps storage usage down.
CREATE TABLE IF NOT EXISTS pdf_notes (
    id BIGSERIAL PRIMARY KEY,
    organization_id BIGINT NULL,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    created_by_user_id BIGINT NULL,
    file_name VARCHAR(255) NULL,
    original_size BIGINT NULL,
    stored_size BIGINT NULL,
    created_at TIMESTAMP NULL,
    updated_at TIMESTAMP NULL,
    created_by VARCHAR(255) NULL,
    updated_by VARCHAR(255) NULL,
    version BIGINT NULL
);

-- Lessons: allow a lesson's PDF notes to be either an external URL (existing
-- behaviour) or a self-hosted PdfNote picked from the faculty's library.
ALTER TABLE lessons ADD COLUMN IF NOT EXISTS pdf_source VARCHAR(10) NOT NULL DEFAULT 'URL';
ALTER TABLE lessons ADD COLUMN IF NOT EXISTS pdf_note_id BIGINT NULL;

-- Company Questions: same Self-hosted / URL choice for PDF tiles.
ALTER TABLE company_question_kits ADD COLUMN IF NOT EXISTS pdf_source VARCHAR(10) NOT NULL DEFAULT 'URL';
ALTER TABLE company_question_kits ADD COLUMN IF NOT EXISTS pdf_note_id BIGINT NULL;