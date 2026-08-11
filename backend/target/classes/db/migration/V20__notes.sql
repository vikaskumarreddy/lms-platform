-- Student personal notes, optionally tied to a lesson.
CREATE TABLE notes (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    lesson_id BIGINT,
    title VARCHAR(255) NOT NULL DEFAULT 'Untitled Note',
    content TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    version BIGINT DEFAULT 0,
    created_by VARCHAR(255),
    updated_by VARCHAR(255)
);

CREATE INDEX idx_notes_user ON notes(user_id);
CREATE INDEX idx_notes_lesson ON notes(lesson_id);
