-- PDF documents uploaded/edited through the admin portal "PDF Tools" editor.
-- The PDF bytes live on disk (gzipped), this table holds metadata only.
CREATE TABLE IF NOT EXISTS pdf_documents (
    id BIGSERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    file_name VARCHAR(255),
    page_count INT,
    original_size BIGINT,
    stored_size BIGINT,
    created_by_user_id BIGINT,
    organization_id BIGINT,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    created_by VARCHAR(255),
    updated_by VARCHAR(255),
    version BIGINT DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_pdf_documents_org ON pdf_documents(organization_id);
