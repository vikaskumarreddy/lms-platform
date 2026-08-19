package com.institute.lms.exception;

/**
 * A uniqueness constraint would be violated. Maps to 409.
 *
 * <p>For users, remember that email is unique <em>per organization</em>
 * ({@code uk_users_org_email}), not globally — so the message should never imply
 * that an email is taken platform-wide when it is only taken inside this tenant.
 */
public class DuplicateResourceException extends ApiException {

    public DuplicateResourceException(String message) {
        super(ErrorCode.DUPLICATE_RESOURCE, message);
    }

    /** Builds an "Email admin@x.com already exists in this organization" style message. */
    public static DuplicateResourceException of(String resource, String field, Object value) {
        DuplicateResourceException ex = new DuplicateResourceException(
                resource + " with " + field + " '" + value + "' already exists");
        ex.detail("resource", resource).detail("field", field).detail("value", String.valueOf(value));
        return ex;
    }
}
