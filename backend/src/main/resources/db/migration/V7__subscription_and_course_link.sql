-- Axisora Forge Academy LMS - V7: Link courses to subscription plans, fix delete cascades

-- Add plan_id to courses to link with subscription plans
ALTER TABLE courses ADD COLUMN IF NOT EXISTS plan_id BIGINT REFERENCES subscription_plans(id);

-- Add ON DELETE CASCADE for lessons referenced by progress/bookmarks so updating/deleting courses works
ALTER TABLE progress DROP CONSTRAINT IF EXISTS progress_lesson_id_fkey;
ALTER TABLE progress ADD CONSTRAINT progress_lesson_id_fkey FOREIGN KEY (lesson_id) REFERENCES lessons(id) ON DELETE CASCADE;

ALTER TABLE bookmarks DROP CONSTRAINT IF EXISTS bookmarks_lesson_id_fkey;
ALTER TABLE bookmarks ADD CONSTRAINT bookmarks_lesson_id_fkey FOREIGN KEY (lesson_id) REFERENCES lessons(id) ON DELETE CASCADE;

-- Add ON DELETE CASCADE for modules referenced by lessons
ALTER TABLE lessons DROP CONSTRAINT IF EXISTS lessons_module_id_fkey;
ALTER TABLE lessons ADD CONSTRAINT lessons_module_id_fkey FOREIGN KEY (module_id) REFERENCES modules(id) ON DELETE CASCADE;

-- Add ON DELETE CASCADE for courses referenced by modules/enrollments
ALTER TABLE modules DROP CONSTRAINT IF EXISTS modules_course_id_fkey;
ALTER TABLE modules ADD CONSTRAINT modules_course_id_fkey FOREIGN KEY (course_id) REFERENCES courses(id) ON DELETE CASCADE;

ALTER TABLE enrollments DROP CONSTRAINT IF EXISTS enrollments_course_id_fkey;
ALTER TABLE enrollments ADD CONSTRAINT enrollments_course_id_fkey FOREIGN KEY (course_id) REFERENCES courses(id) ON DELETE CASCADE;

-- Add ON DELETE SET NULL (instead of RESTRICT) for course instructor
ALTER TABLE courses DROP CONSTRAINT IF EXISTS courses_instructor_id_fkey;
ALTER TABLE courses ADD CONSTRAINT courses_instructor_id_fkey FOREIGN KEY (instructor_id) REFERENCES users(id) ON DELETE SET NULL;