package com.institute.lms.exception;

/** A requested entity does not exist, or is not visible to the current tenant. Maps to 404. */
public class ResourceNotFoundException extends ApiException {

    public ResourceNotFoundException(String message) {
        super(ErrorCode.RESOURCE_NOT_FOUND, message);
    }

    public ResourceNotFoundException(ErrorCode code, String message) {
        super(code, message);
    }

    /**
     * Builds a "Course with id 42 was not found" style message.
     *
     * <p>Note this is also the correct response when a row exists but belongs to
     * another tenant — leaking "exists but forbidden" would confirm the presence of
     * another organization's data.
     */
    public static ResourceNotFoundException of(String resource, Object id) {
        ResourceNotFoundException ex = new ResourceNotFoundException(
                resource + " with id " + id + " was not found");
        ex.detail("resource", resource).detail("id", String.valueOf(id));
        return ex;
    }
}
