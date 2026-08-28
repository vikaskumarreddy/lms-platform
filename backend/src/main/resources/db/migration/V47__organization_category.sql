-- Broad institution category (SCHOOL/COLLEGE/ACADEMY/TRAINING_INSTITUTE/OTHER) driving
-- category-aware admin menus. Nullable and additive; existing rows are left NULL and
-- treated as OTHER by the application layer, so no existing organization is affected.
ALTER TABLE organizations ADD COLUMN category VARCHAR(30) NULL;
