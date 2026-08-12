-- Certificates issued to students by the institute for completed courses.
CREATE TABLE certificates (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    institute_name VARCHAR(255) NOT NULL,
    course_name VARCHAR(255) NOT NULL,
    duration VARCHAR(100),
    credential_id VARCHAR(100) UNIQUE,
    issue_date DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    version BIGINT DEFAULT 0,
    created_by VARCHAR(255),
    updated_by VARCHAR(255)
);

CREATE INDEX idx_certificates_user ON certificates(user_id);
