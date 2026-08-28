-- Organization Razorpay configuration (one per org, optional)
CREATE TABLE org_razorpay_config (
  id BIGSERIAL PRIMARY KEY,
  organization_id BIGINT NOT NULL UNIQUE,
  razorpay_key_id VARCHAR(255) NOT NULL,
  razorpay_key_secret VARCHAR(255) NOT NULL,
  razorpay_webhook_secret VARCHAR(255),
  amount_per_student BIGINT DEFAULT 0,
  payment_enabled BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE
);
CREATE INDEX idx_org_razorpay_config ON org_razorpay_config(organization_id);

-- Student payment status: tracks payment method (CASH/ONLINE) and completion
CREATE TABLE student_payment_info (
  id BIGSERIAL PRIMARY KEY,
  organization_id BIGINT NOT NULL,
  student_id BIGINT NOT NULL,
  payment_method VARCHAR(20) NOT NULL DEFAULT 'CASH',
  payment_status VARCHAR(50) NOT NULL DEFAULT 'PENDING',
  amount_due BIGINT DEFAULT 0,
  paid_at TIMESTAMP NULL,
  notes VARCHAR(500),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
  FOREIGN KEY (student_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE (student_id, organization_id)
);
CREATE INDEX idx_org_student_payment ON student_payment_info(organization_id, student_id);
CREATE INDEX idx_payment_status ON student_payment_info(organization_id, payment_status);

-- Razorpay orders (tracks each payment attempt)
CREATE TABLE razorpay_orders (
  id BIGSERIAL PRIMARY KEY,
  organization_id BIGINT NOT NULL,
  student_id BIGINT,
  razorpay_order_id VARCHAR(100) UNIQUE NOT NULL,
  razorpay_payment_id VARCHAR(100) UNIQUE,
  razorpay_signature VARCHAR(255),
  amount BIGINT NOT NULL,
  currency VARCHAR(3) DEFAULT 'INR',
  status VARCHAR(50) NOT NULL DEFAULT 'PENDING',
  attempt_count INT DEFAULT 1,
  last_error VARCHAR(500),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
  FOREIGN KEY (student_id) REFERENCES users(id) ON DELETE SET NULL
);
CREATE INDEX idx_org_student_orders ON razorpay_orders(organization_id, student_id);
CREATE INDEX idx_order_id ON razorpay_orders(razorpay_order_id);
CREATE INDEX idx_payment_id ON razorpay_orders(razorpay_payment_id);
CREATE INDEX idx_status ON razorpay_orders(status);

-- Payment refunds
CREATE TABLE payment_refunds (
  id BIGSERIAL PRIMARY KEY,
  organization_id BIGINT NOT NULL,
  student_id BIGINT,
  razorpay_refund_id VARCHAR(100) UNIQUE,
  razorpay_payment_id VARCHAR(100),
  amount BIGINT NOT NULL,
  reason VARCHAR(255),
  status VARCHAR(50),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
  FOREIGN KEY (student_id) REFERENCES users(id) ON DELETE SET NULL
);
CREATE INDEX idx_refund_id ON payment_refunds(razorpay_refund_id);
