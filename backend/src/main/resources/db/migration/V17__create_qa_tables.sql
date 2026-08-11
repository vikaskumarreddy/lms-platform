-- Q&A tables: questions and answers
CREATE TABLE questions (
    id BIGSERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    content TEXT,
    category VARCHAR(100),
    author_name VARCHAR(255),
    is_answered BOOLEAN DEFAULT FALSE,
    answer_count INTEGER DEFAULT 0,
    view_count INTEGER DEFAULT 0,
    vote_count INTEGER DEFAULT 0,
    plan_id BIGINT,
    batch_id BIGINT,
    user_id BIGINT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    version BIGINT DEFAULT 0,
    created_by VARCHAR(255),
    updated_by VARCHAR(255)
);

CREATE TABLE answers (
    id BIGSERIAL PRIMARY KEY,
    question_id BIGINT NOT NULL,
    content TEXT NOT NULL,
    author_name VARCHAR(255),
    is_accepted BOOLEAN DEFAULT FALSE,
    vote_count INTEGER DEFAULT 0,
    user_id BIGINT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    version BIGINT DEFAULT 0,
    created_by VARCHAR(255),
    updated_by VARCHAR(255),
    CONSTRAINT fk_answer_question FOREIGN KEY (question_id) REFERENCES questions(id) ON DELETE CASCADE
);

CREATE INDEX idx_questions_batch ON questions(batch_id);
CREATE INDEX idx_questions_plan ON questions(plan_id);
CREATE INDEX idx_questions_user ON questions(user_id);
CREATE INDEX idx_questions_category ON questions(category);
CREATE INDEX idx_answers_question ON answers(question_id);