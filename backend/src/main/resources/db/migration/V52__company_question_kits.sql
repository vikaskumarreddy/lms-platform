-- Company Questions: an admin-authored "tile" per company, either a full in-app
-- question paper (reusing the existing assessment-paper engine via
-- AssessmentType.COMPANY_KIT) or a pasted PDF URL viewed in the mobile in-app browser.
CREATE TABLE company_question_kits (
    id BIGSERIAL PRIMARY KEY,
    organization_id BIGINT NULL,
    company_name VARCHAR(255) NOT NULL,
    logo_url VARCHAR(1000) NULL,
    tags VARCHAR(500) NULL,
    mode VARCHAR(20) NOT NULL DEFAULT 'CONTENT',
    pdf_url VARCHAR(1000) NULL,
    description TEXT NULL,
    is_published BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NULL,
    updated_at TIMESTAMP NULL,
    created_by VARCHAR(255) NULL,
    updated_by VARCHAR(255) NULL,
    version BIGINT NULL
);
