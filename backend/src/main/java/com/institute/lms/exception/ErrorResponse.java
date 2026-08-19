package com.institute.lms.exception;

import com.fasterxml.jackson.annotation.JsonInclude;

import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * The single error envelope returned by {@link GlobalExceptionHandler} for every
 * failed request.
 *
 * <p>The {@code error} field is a deliberate duplicate of {@code message}: the
 * existing admin portal reads {@code err.error?.error || err.error?.message}
 * (see {@code organizations.component.ts}), so dropping it would silently turn
 * every existing error message into "Unknown error". New frontend code should
 * read {@code code} + {@code message} + {@code details}.
 *
 * <p>{@code details} carries the machine-usable context — for a quota breach that
 * is the limit, current usage and the plan/add-on that would resolve it, which is
 * what lets the UI render a real upgrade call-to-action.
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public class ErrorResponse {

    private String code;
    private int status;
    private String message;
    /** Legacy alias of {@link #message} — kept for the existing portal error handling. */
    private String error;
    private String path;
    private LocalDateTime timestamp;
    private Map<String, Object> details;

    public ErrorResponse() {
        this.timestamp = LocalDateTime.now();
    }

    public ErrorResponse(ErrorCode code, String message, String path, Map<String, Object> details) {
        this();
        this.code = code != null ? code.name() : ErrorCode.INTERNAL_ERROR.name();
        this.status = code != null ? code.getStatus().value() : 500;
        this.message = message;
        this.error = message;
        this.path = path;
        this.details = details != null && !details.isEmpty() ? new LinkedHashMap<>(details) : null;
    }

    public String getCode() {
        return code;
    }

    public void setCode(String code) {
        this.code = code;
    }

    public int getStatus() {
        return status;
    }

    public void setStatus(int status) {
        this.status = status;
    }

    public String getMessage() {
        return message;
    }

    /** Sets both {@code message} and its legacy {@code error} alias so they never diverge. */
    public void setMessage(String message) {
        this.message = message;
        this.error = message;
    }

    public String getError() {
        return error;
    }

    public String getPath() {
        return path;
    }

    public void setPath(String path) {
        this.path = path;
    }

    public LocalDateTime getTimestamp() {
        return timestamp;
    }

    public void setTimestamp(LocalDateTime timestamp) {
        this.timestamp = timestamp;
    }

    public Map<String, Object> getDetails() {
        return details;
    }

    public void setDetails(Map<String, Object> details) {
        this.details = details;
    }
}
