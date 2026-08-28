package com.institute.lms.entity;

/**
 * Which parent an assessment question / response belongs to.
 *
 * <p>Questions are shared between assignments and exams — the authoring UI, the
 * student paper and the auto-grader are identical for both — so the parent is
 * addressed polymorphically by (type, id) rather than by two near-identical
 * table sets.
 */
public enum AssessmentType {
    ASSIGNMENT,
    EXAM,
    COMPANY_KIT;

    /**
     * Lenient parse used by the path-variable binding ("exam", "EXAM", "exams",
     * "company-kit" all work). Hyphens are normalized to underscores before the
     * trailing-"S" strip so multi-word types like COMPANY_KIT survive a hyphenated
     * URL segment — existing single-word inputs have no hyphens, so this is a
     * no-op for them.
     */
    public static AssessmentType from(String raw) {
        if (raw == null) throw new IllegalArgumentException("Assessment type is required");
        String normalized = raw.trim().toUpperCase().replace('-', '_');
        if (normalized.endsWith("S")) normalized = normalized.substring(0, normalized.length() - 1);
        return AssessmentType.valueOf(normalized);
    }
}
