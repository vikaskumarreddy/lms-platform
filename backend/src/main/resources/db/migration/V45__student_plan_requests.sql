-- Upgrade requests raised by students from the mobile app. The admin decides;
-- nothing about the student's actual plan changes until they approve.
CREATE TABLE student_plan_requests (
  id BIGSERIAL PRIMARY KEY,
  organization_id BIGINT NOT NULL,
  student_id BIGINT NOT NULL,
  requested_plan_id BIGINT NOT NULL,
  current_plan_id BIGINT,
  status VARCHAR(20) NOT NULL DEFAULT 'PENDING', -- PENDING, APPROVED, REJECTED
  student_note VARCHAR(500),
  decision_note VARCHAR(500),
  decided_by VARCHAR(255),
  decided_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  created_by VARCHAR(255),
  updated_by VARCHAR(255),
  version BIGINT NOT NULL DEFAULT 0,
  FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
  FOREIGN KEY (student_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX idx_plan_req_org_status ON student_plan_requests(organization_id, status);
CREATE INDEX idx_plan_req_student ON student_plan_requests(student_id);

-- At most one open request per student, so repeated taps on "Upgrade Now" cannot
-- flood the admin queue with duplicates of the same ask.
CREATE UNIQUE INDEX idx_plan_req_one_pending
  ON student_plan_requests(student_id)
  WHERE status = 'PENDING';
