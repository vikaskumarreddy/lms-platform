-- Admin-configurable system settings (Firebase, Razorpay, JWT, etc.). Values that are
-- credentials/secrets are marked is_secret = true so the admin portal can mask them.
CREATE TABLE system_configs (
    id BIGSERIAL PRIMARY KEY,
    config_key VARCHAR(150) NOT NULL UNIQUE,
    config_value TEXT,
    category VARCHAR(50) NOT NULL DEFAULT 'GENERAL',
    description VARCHAR(500),
    is_secret BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    version BIGINT DEFAULT 0,
    created_by VARCHAR(255),
    updated_by VARCHAR(255)
);

CREATE INDEX idx_system_configs_category ON system_configs(category);

INSERT INTO system_configs (config_key, config_value, category, description, is_secret) VALUES
    ('firebase.apiKey', '', 'FIREBASE', 'Firebase Web/Android API Key', true),
    ('firebase.appId', '', 'FIREBASE', 'Firebase App ID', true),
    ('firebase.messagingSenderId', '', 'FIREBASE', 'Firebase Cloud Messaging Sender ID', true),
    ('firebase.projectId', '', 'FIREBASE', 'Firebase Project ID', false),
    ('razorpay.keyId', '', 'PAYMENTS', 'Razorpay Key ID', true),
    ('razorpay.keySecret', '', 'PAYMENTS', 'Razorpay Key Secret', true),
    ('jwt.secret', '', 'SECURITY', 'JWT signing secret', true),
    ('jwt.expiration', '86400000', 'SECURITY', 'JWT token expiration (ms)', false),
    ('jwt.refreshExpiration', '604800000', 'SECURITY', 'JWT refresh token expiration (ms)', false);
