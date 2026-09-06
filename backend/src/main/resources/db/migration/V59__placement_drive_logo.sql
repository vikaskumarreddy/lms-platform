-- Companies now carry an optional logo (URL) so placement drives can be shown
-- as image cards in the mobile app. Null = fall back to the company initial badge.
ALTER TABLE placement_drives ADD COLUMN company_logo_url VARCHAR(1000);