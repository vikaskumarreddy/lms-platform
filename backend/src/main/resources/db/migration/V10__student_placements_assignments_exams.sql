-- Axisora Forge Academy LMS - V10: Student Placements, Assignments, Exams
-- Recreates the assignments/exams tables with the new schema.
-- The old tables were created by V1 with a legacy schema (lesson_id/max_marks/deadline,
-- start_time/has_negative_marking). These tables are empty, so we drop them first
-- (in foreign-key dependency order) and recreate them matching the current entities.

-- Drop dependent tables first (they reference assignments/exams)
DROP TABLE IF EXISTS assignment_submissions;
DROP TABLE IF EXISTS exam_results;
DROP TABLE IF EXISTS assignments;
DROP TABLE IF EXISTS exams;

-- Create student_placements table
CREATE TABLE student_placements (
    id BIGSERIAL PRIMARY KEY,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    company_name VARCHAR(255) NOT NULL,
    role VARCHAR(255) NOT NULL,
    package_amount DOUBLE PRECISION,
    placed_date TIMESTAMP,
    description TEXT,
    is_placed BOOLEAN NOT NULL DEFAULT FALSE
);

-- Create assignments table
CREATE TABLE assignments (
    id BIGSERIAL PRIMARY KEY,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    due_date TIMESTAMP,
    total_marks INTEGER,
    batch_id BIGINT,
    course_id BIGINT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

-- Create assignment_submissions table
CREATE TABLE assignment_submissions (
    id BIGSERIAL PRIMARY KEY,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    assignment_id BIGINT NOT NULL REFERENCES assignments(id) ON DELETE CASCADE,
    submission TEXT,
    submitted_at TIMESTAMP,
    marks_obtained INTEGER,
    feedback TEXT,
    is_graded BOOLEAN NOT NULL DEFAULT FALSE
);

-- Create exams table
CREATE TABLE exams (
    id BIGSERIAL PRIMARY KEY,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    exam_date TIMESTAMP,
    duration_minutes INTEGER,
    total_marks INTEGER,
    passing_marks INTEGER,
    batch_id BIGINT,
    course_id BIGINT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

-- Create exam_submissions table
CREATE TABLE exam_submissions (
    id BIGSERIAL PRIMARY KEY,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    exam_id BIGINT NOT NULL REFERENCES exams(id) ON DELETE CASCADE,
    answers TEXT,
    submitted_at TIMESTAMP,
    marks_obtained INTEGER,
    remarks TEXT,
    is_graded BOOLEAN NOT NULL DEFAULT FALSE
);

-- Create indexes for better performance
CREATE INDEX idx_student_placements_user_id ON student_placements(user_id);
CREATE INDEX idx_student_placements_is_placed ON student_placements(is_placed);
CREATE INDEX idx_assignments_batch_id ON assignments(batch_id);
CREATE INDEX idx_assignments_course_id ON assignments(course_id);
CREATE INDEX idx_assignment_submissions_user_id ON assignment_submissions(user_id);
CREATE INDEX idx_assignment_submissions_assignment_id ON assignment_submissions(assignment_id);
CREATE INDEX idx_exams_batch_id ON exams(batch_id);
CREATE INDEX idx_exams_course_id ON exams(course_id);
CREATE INDEX idx_exam_submissions_user_id ON exam_submissions(user_id);
CREATE INDEX idx_exam_submissions_exam_id ON exam_submissions(exam_id);