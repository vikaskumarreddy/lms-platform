CREATE TABLE support_requests (
    id BIGSERIAL PRIMARY KEY,
    organization_id BIGINT NULL,
    student_id BIGINT NOT NULL,
    drive_id BIGINT NULL,
    company_name VARCHAR(255) NOT NULL,
    message TEXT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'PENDING',
    admin_response TEXT NULL,
    decided_at TIMESTAMP NULL,
    created_at TIMESTAMP NULL,
    updated_at TIMESTAMP NULL,
    created_by VARCHAR(255) NULL,
    updated_by VARCHAR(255) NULL,
    version BIGINT NULL
);

CREATE INDEX idx_support_requests_org_status ON support_requests (organization_id, status);
CREATE INDEX idx_support_requests_student ON support_requests (student_id);
