CREATE TABLE company_kit_favorites (
    id BIGSERIAL PRIMARY KEY,
    organization_id BIGINT NULL,
    student_id BIGINT NOT NULL,
    kit_id BIGINT NOT NULL,
    created_at TIMESTAMP NULL,
    updated_at TIMESTAMP NULL,
    created_by VARCHAR(255) NULL,
    updated_by VARCHAR(255) NULL,
    version BIGINT NULL,
    CONSTRAINT uq_company_kit_favorites_student_kit UNIQUE (student_id, kit_id)
);
