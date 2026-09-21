-- =====================================================================
-- V63: Lesson/study time tracking.
--
-- The student dashboard's "Time Spending" panel and the course-progress
-- widgets have always been driven by numbers the backend never collected:
-- nothing anywhere recorded *how long* a student actually spent in a
-- lesson, so the trend chart had no source and always rendered empty.
--
-- One row per study session. A session is opened when a lesson player is
-- entered and closed when it is left (or capped server-side if the app is
-- killed while a session is still open, so a crashed client cannot bill
-- hours it never spent).
-- =====================================================================

CREATE TABLE lesson_time_log (
    id BIGSERIAL PRIMARY KEY,
    organization_id BIGINT,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    lesson_id BIGINT REFERENCES lessons(id) ON DELETE SET NULL,
    course_id BIGINT,
    -- LESSON (video/notes in the player), PDF, QUIZ ... lets study time be
    -- split by activity later without another table.
    source VARCHAR(20) NOT NULL DEFAULT 'LESSON',
    started_at TIMESTAMPTZ NOT NULL,
    ended_at TIMESTAMPTZ,
    duration_seconds INTEGER NOT NULL DEFAULT 0 CHECK (duration_seconds >= 0),
    -- Denormalised calendar day so monthly/per-day rollups don't need a
    -- time-zone re-derivation of started_at on every query.
    activity_date DATE NOT NULL,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    created_by VARCHAR(255),
    updated_by VARCHAR(255),
    version BIGINT
);

-- Dashboard trend: "my minutes per month", newest first.
CREATE INDEX idx_lesson_time_log_user_date ON lesson_time_log(user_id, activity_date DESC);
-- Tenant rollups and the "who studied what" admin view.
CREATE INDEX idx_lesson_time_log_org_date ON lesson_time_log(organization_id, activity_date DESC);
-- Closing the open session for a lesson the student just left.
CREATE INDEX idx_lesson_time_log_lesson ON lesson_time_log(lesson_id);

-- Only one *open* session may exist per student at a time; a client that
-- opens a second player without closing the first would otherwise accrue
-- overlapping time. Partial indexes are the cheapest way to enforce that in
-- Postgres without a trigger.
CREATE UNIQUE INDEX uk_lesson_time_log_open_session
    ON lesson_time_log(user_id)
    WHERE ended_at IS NULL;