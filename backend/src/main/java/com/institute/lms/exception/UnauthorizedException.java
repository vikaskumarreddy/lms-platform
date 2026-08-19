package com.institute.lms.exception;

/**
 * Authentication is missing/invalid (401), or the caller is authenticated but lacks
 * the required role (403 — use {@link #forbidden}).
 */
public class UnauthorizedException extends ApiException {

    public UnauthorizedException(String message) {
        super(ErrorCode.UNAUTHORIZED, message);
    }

    private UnauthorizedException(ErrorCode code, String message) {
        super(code, message);
    }

    /** Authenticated but not permitted — 403 rather than 401. */
    public static UnauthorizedException forbidden(String message) {
        return new UnauthorizedException(ErrorCode.FORBIDDEN, message);
    }

    /** Standard message for endpoints restricted to a specific role. */
    public static UnauthorizedException requiresRole(String role) {
        UnauthorizedException ex = new UnauthorizedException(ErrorCode.FORBIDDEN,
                "Access denied: " + role + " role required");
        ex.detail("requiredRole", role);
        return ex;
    }
}
