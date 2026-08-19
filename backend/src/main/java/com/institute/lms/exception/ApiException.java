package com.institute.lms.exception;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Base class for every deliberately-thrown application error.
 *
 * <p>Extends {@link RuntimeException} on purpose: the codebase already throws bare
 * {@code RuntimeException("Access denied: ...")} from ~20 controllers and
 * {@link GlobalExceptionHandler} still has a fallback branch for those. Because
 * Spring dispatches to the most specific {@code @ExceptionHandler}, subclasses of
 * this type get the typed treatment while untouched controllers keep working.
 *
 * <p>Carries an {@link ErrorCode} (which fixes the HTTP status) plus a free-form
 * {@code details} map that is serialised into {@link ErrorResponse#getDetails()}.
 */
public class ApiException extends RuntimeException {

    private final ErrorCode code;
    private final Map<String, Object> details = new LinkedHashMap<>();

    public ApiException(ErrorCode code, String message) {
        super(message);
        this.code = code != null ? code : ErrorCode.INTERNAL_ERROR;
    }

    public ApiException(ErrorCode code, String message, Throwable cause) {
        super(message, cause);
        this.code = code != null ? code : ErrorCode.INTERNAL_ERROR;
    }

    public ErrorCode getCode() {
        return code;
    }

    public Map<String, Object> getDetails() {
        return details;
    }

    /** Adds a detail entry, skipping nulls so the envelope stays clean. Fluent. */
    public ApiException detail(String key, Object value) {
        if (key != null && value != null) {
            details.put(key, value);
        }
        return this;
    }
}
