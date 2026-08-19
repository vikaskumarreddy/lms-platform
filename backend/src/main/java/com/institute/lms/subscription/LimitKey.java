package com.institute.lms.subscription;

import com.institute.lms.exception.ErrorCode;

/**
 * The countable allowances a plan grants. Each key exists in three places, and this
 * enum is the single point that ties them together:
 *
 * <ul>
 *   <li>a column on {@code org_subscriptions} (the plan catalog) — {@link #getDbColumn()}</li>
 *   <li>a key inside {@code org_subscription_instances.limits_snapshot} JSON, which is
 *       what actually gets enforced (the snapshot is frozen at purchase so that editing
 *       a plan's limits never silently reprices or re-limits existing tenants)</li>
 *   <li>an {@link ErrorCode} returned when the limit is breached — {@link #getErrorCode()}</li>
 * </ul>
 *
 * <p>The enum constant name is the JSON key, in both {@code limits_snapshot} and the
 * {@code details.limitKey} field of an error response. Renaming a constant is a
 * breaking API change.
 *
 * <p>A null or absent value means <em>unlimited</em>, which is how Enterprise and
 * custom-limit agreements are expressed. {@link #UNLIMITED} is the sentinel used
 * internally once resolved.
 */
public enum LimitKey {

    MAX_ACTIVE_STUDENTS("max_active_students", "active students", "active student",
            ErrorCode.QUOTA_ACTIVE_STUDENTS_EXCEEDED),

    MAX_FACULTY_ACCOUNTS("max_faculty_accounts", "faculty seats", "faculty seat",
            ErrorCode.QUOTA_FACULTY_ACCOUNTS_EXCEEDED),

    MAX_BRANCHES("max_branches", "branches", "branch",
            ErrorCode.QUOTA_BRANCHES_EXCEEDED),

    MAX_ORGANIZATIONS("max_organizations", "organizations", "organization",
            ErrorCode.QUOTA_ORGANIZATIONS_EXCEEDED),

    STORAGE_GB("storage_gb", "GB of storage", "GB",
            ErrorCode.QUOTA_STORAGE_EXCEEDED),

    INCLUDED_TRAINING_HOURS("included_training_hours", "training hours", "training hour",
            ErrorCode.QUOTA_TRAINING_HOURS_EXCEEDED);

    /** Sentinel meaning "no ceiling". Stored as NULL in the DB and absent from JSON. */
    public static final long UNLIMITED = -1L;

    private final String dbColumn;
    private final String pluralLabel;
    private final String singularLabel;
    private final ErrorCode errorCode;

    LimitKey(String dbColumn, String pluralLabel, String singularLabel, ErrorCode errorCode) {
        this.dbColumn = dbColumn;
        this.pluralLabel = pluralLabel;
        this.singularLabel = singularLabel;
        this.errorCode = errorCode;
    }

    public String getDbColumn() {
        return dbColumn;
    }

    /** Human plural used in error messages and usage meters, e.g. "faculty seats". */
    public String getPluralLabel() {
        return pluralLabel;
    }

    public String getSingularLabel() {
        return singularLabel;
    }

    public ErrorCode getErrorCode() {
        return errorCode;
    }

    public static boolean isUnlimited(Long value) {
        return value == null || value == UNLIMITED;
    }

    /** Lenient lookup for values read back out of JSON; returns null when unrecognised. */
    public static LimitKey fromKey(String key) {
        if (key == null) return null;
        for (LimitKey k : values()) {
            if (k.name().equalsIgnoreCase(key) || k.dbColumn.equalsIgnoreCase(key)) {
                return k;
            }
        }
        return null;
    }
}
