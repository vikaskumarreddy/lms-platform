package com.institute.lms.exception;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.Map;

/**
 * Centralized exception handling so controllers can throw plain RuntimeExceptions
 * (e.g. "Access denied: ...") without leaking stack traces to the client as raw
 * 500 Internal Server Errors. Access-denied style messages are mapped to 403,
 * "not found" style messages to 404, everything else to 400.
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(RuntimeException.class)
    public ResponseEntity<Map<String, Object>> handleRuntimeException(RuntimeException ex) {
        String message = ex.getMessage() != null ? ex.getMessage() : "An unexpected error occurred";
        HttpStatus status = HttpStatus.BAD_REQUEST;

        String lower = message.toLowerCase();
        if (lower.contains("access denied") || lower.contains("role required") || lower.contains("forbidden")) {
            status = HttpStatus.FORBIDDEN;
        } else if (lower.contains("not found")) {
            status = HttpStatus.NOT_FOUND;
        }

        return ResponseEntity.status(status).body(Map.of(
                "error", message,
                "status", status.value()
        ));
    }
}

