package com.institute.lms.subscription;

/**
 * The events that make a student "active" for a billing month, and therefore billable.
 *
 * <p>This list <em>is</em> the commercial definition of an active student, so it should
 * change only with a deliberate pricing decision: adding an event here widens what
 * customers pay for. Each constant maps to one place in the application that calls
 * {@code ActivityMeterService.record(...)}.
 *
 * <p>Note what is absent. Creating a student account is not activity — a tenant can
 * import their whole alumni roll without paying for any of them. Only a student who
 * actually uses the platform in a given month consumes an active-student seat.
 */
public enum ActivityType {

    /** The student signed in. Recorded from the authentication path. */
    LOGIN("Signed in"),

    /** Opened a lesson, note or learning material. */
    CONTENT_ACCESS("Accessed content"),

    /** Marked present for, or joined, a class. */
    CLASS_ATTENDANCE("Attended a class"),

    /** Submitted an assignment, exam or quiz. */
    ASSESSMENT_SUBMISSION("Submitted an assessment"),

    /** Applied to a placement drive. */
    PLACEMENT_APPLICATION("Applied for a placement");

    private final String label;

    ActivityType(String label) {
        this.label = label;
    }

    public String getLabel() {
        return label;
    }

    public static ActivityType fromName(String raw) {
        if (raw == null) {
            return null;
        }
        for (ActivityType t : values()) {
            if (t.name().equalsIgnoreCase(raw.trim())) {
                return t;
            }
        }
        return null;
    }
}
