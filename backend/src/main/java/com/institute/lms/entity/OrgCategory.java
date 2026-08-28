package com.institute.lms.entity;

/**
 * Broad category of institution an {@link Organization} represents. Drives which
 * admin-portal menu items are surfaced (e.g. Daily Attendance for {@code SCHOOL}).
 * Existing organizations created before this field existed resolve to {@code OTHER}.
 */
public enum OrgCategory {
    SCHOOL,
    COLLEGE,
    ACADEMY,
    TRAINING_INSTITUTE,
    OTHER
}
