package com.institute.lms.exception;

import jakarta.servlet.http.HttpServletRequest;
import org.hibernate.exception.ConstraintViolationException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.validation.FieldError;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.servlet.NoHandlerFoundException;
import org.springframework.web.servlet.resource.NoResourceFoundException;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Centralised exception handling. Every failure leaves the API as a single
 * {@link ErrorResponse} envelope carrying a machine-readable {@link ErrorCode},
 * a human message, and a {@code details} map.
 *
 * <p>Handlers are ordered from most to least specific. Spring always dispatches to
 * the most specific match, so the {@link #handleApiException} branch takes precedence
 * for anything deliberately thrown by the application.
 *
 * <p>The final {@link #handleRuntimeException} branch preserves the original
 * message-sniffing behaviour on purpose: roughly twenty controllers still throw bare
 * {@code RuntimeException("Access denied: Admin role required")} and rely on it being
 * translated to 403. Those are migrated to {@link UnauthorizedException} incrementally;
 * until then this fallback keeps them behaving exactly as before.
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    /** Postgres reports the violated constraint as {@code constraint "name"}. */
    private static final Pattern CONSTRAINT_PATTERN = Pattern.compile("constraint \"([^\"]+)\"");

    /** Deliberately-thrown application errors — quota, entitlement, billing, not-found, etc. */
    @ExceptionHandler(ApiException.class)
    public ResponseEntity<ErrorResponse> handleApiException(ApiException ex, HttpServletRequest request) {
        ErrorCode code = ex.getCode();
        // Commercial blocks (quota/entitlement/expiry) are expected traffic, not defects —
        // log at INFO so they don't pollute error dashboards, but keep them traceable.
        if (code.getStatus().is5xxServerError()) {
            log.error("[{}] {}", code, ex.getMessage(), ex);
        } else {
            log.info("[{}] {} ({})", code, ex.getMessage(), request.getRequestURI());
        }
        return build(code, ex.getMessage(), request, ex.getDetails());
    }

    /** Bean-validation failures on {@code @Valid} request bodies. */
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ErrorResponse> handleValidation(MethodArgumentNotValidException ex,
                                                          HttpServletRequest request) {
        Map<String, Object> fields = new LinkedHashMap<>();
        for (FieldError fe : ex.getBindingResult().getFieldErrors()) {
            fields.put(fe.getField(), fe.getDefaultMessage());
        }
        String message = fields.isEmpty()
                ? "The submitted data is invalid."
                : "Please correct: " + String.join(", ", fields.keySet());
        return build(ErrorCode.VALIDATION_FAILED, message, request, Map.of("fields", fields));
    }

    @ExceptionHandler({MissingServletRequestParameterException.class,
                       MethodArgumentTypeMismatchException.class,
                       HttpMessageNotReadableException.class})
    public ResponseEntity<ErrorResponse> handleMalformedRequest(Exception ex, HttpServletRequest request) {
        return build(ErrorCode.BAD_REQUEST, "The request could not be read: " + ex.getMessage(), request, null);
    }

    /**
     * A request for a path that does not map to a handler or a static resource.
     *
     * <p>Handled explicitly and logged at DEBUG. Without this it falls through to
     * {@link #handleUnexpected}, which logs a full stack trace at ERROR — and since
     * anything polling a non-existent path does so repeatedly (a Prometheus scrape of
     * {@code /actuator/prometheus} runs every few seconds), that buries real errors
     * under thousands of lines of noise. A 404 is an ordinary outcome, not a fault.
     */
    @ExceptionHandler({NoResourceFoundException.class, NoHandlerFoundException.class})
    public ResponseEntity<ErrorResponse> handleNoResource(Exception ex, HttpServletRequest request) {
        log.debug("No handler for {} {}", request.getMethod(), request.getRequestURI());
        return build(ErrorCode.RESOURCE_NOT_FOUND,
                "No endpoint " + request.getMethod() + " " + request.getRequestURI() + ".", request, null);
    }

    /** Right path, wrong verb. A client mistake, so no stack trace. */
    @ExceptionHandler(HttpRequestMethodNotSupportedException.class)
    public ResponseEntity<ErrorResponse> handleMethodNotSupported(HttpRequestMethodNotSupportedException ex,
                                                                  HttpServletRequest request) {
        log.debug("Method {} not supported for {}", request.getMethod(), request.getRequestURI());
        return build(ErrorCode.BAD_REQUEST,
                request.getMethod() + " is not supported on this endpoint. Supported: "
                        + String.join(", ", ex.getSupportedMethods() != null
                                ? ex.getSupportedMethods() : new String[]{"none"}),
                request, null);
    }

    /** Spring Security's own denial, e.g. from a method-level role check. */
    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<ErrorResponse> handleAccessDenied(AccessDeniedException ex, HttpServletRequest request) {
        return build(ErrorCode.FORBIDDEN, "Access denied: you do not have permission to do this.", request, null);
    }

    /**
     * Database constraint violations — a duplicate slug, email, or plan code.
     *
     * <p>Without this, Hibernate's message reaches the client verbatim: the full INSERT
     * statement, every column name, and the constraint. That is unreadable for the
     * administrator who simply reused a slug, and it needlessly publishes the schema.
     * Known constraints are translated into plain language; anything unrecognised gets a
     * generic conflict message, with the detail kept in the server log.
     */
    @ExceptionHandler(DataIntegrityViolationException.class)
    public ResponseEntity<ErrorResponse> handleDataIntegrity(DataIntegrityViolationException ex,
                                                             HttpServletRequest request) {
        String constraint = extractConstraint(ex);
        log.warn("Constraint violation at {} ({})", request.getRequestURI(), constraint, ex);

        String message = switch (constraint == null ? "" : constraint) {
            case "organizations_slug_key" ->
                    "That slug is already taken. Slugs form the tenant's subdomain, so each has to be unique.";
            case "organizations_domain_key" ->
                    "That domain is already assigned to another organization.";
            case "uk_users_org_email" ->
                    "Someone with that email address already exists in this organization.";
            case "uk_org_subscriptions_code" ->
                    "A plan with that code already exists.";
            case "uk_plan_addons_code" ->
                    "An add-on with that code already exists.";
            case "uk_osi_current_per_org" ->
                    "This organization already has a current subscription. Change or renew it instead of adding another.";
            case "uk_opcr_one_pending_per_org" ->
                    "There is already a plan change awaiting a decision for this organization.";
            case "uk_invoices_number", "uk_credit_notes_number" ->
                    "That document number has already been used.";
            case "uk_coupons_code" ->
                    "A coupon with that code already exists.";
            case "uk_sap_org_student_period" ->
                    "That student's activity for this month has already been recorded.";
            case "uk_branches_org_code" ->
                    "A branch with that code already exists in this organization.";
            case "uk_branches_org_primary" ->
                    "This organization already has a primary branch.";
            default -> "That change conflicts with existing data. Something you entered may already be in use.";
        };

        ErrorCode code = ErrorCode.DUPLICATE_RESOURCE;
        return build(code, message, request,
                constraint != null ? Map.of("constraint", constraint) : null);
    }

    /**
     * Digs the constraint name out of the driver's message. Postgres reports it as
     * {@code constraint "name"} at the end of the chain.
     */
    private String extractConstraint(DataIntegrityViolationException ex) {
        if (ex.getCause() instanceof ConstraintViolationException cve && cve.getConstraintName() != null) {
            return cve.getConstraintName();
        }
        Throwable cause = ex.getMostSpecificCause();
        String text = cause != null ? cause.getMessage() : null;
        if (text == null) {
            return null;
        }
        Matcher matcher = CONSTRAINT_PATTERN.matcher(text);
        return matcher.find() ? matcher.group(1) : null;
    }

    /**
     * Legacy fallback for controllers that still throw bare {@code RuntimeException}
     * with the intended status encoded in the message text. Access-denied phrasing maps
     * to 403, "not found" to 404, everything else to 400 — identical to the behaviour
     * before typed exceptions were introduced.
     */
    @ExceptionHandler(RuntimeException.class)
    public ResponseEntity<ErrorResponse> handleRuntimeException(RuntimeException ex, HttpServletRequest request) {
        String message = ex.getMessage() != null ? ex.getMessage() : "An unexpected error occurred";
        String lower = message.toLowerCase();

        ErrorCode code;
        if (lower.contains("access denied") || lower.contains("role required") || lower.contains("forbidden")
                || lower.contains("another organization") || lower.contains("sign in through") || lower.contains("portal")) {
            code = ErrorCode.FORBIDDEN;
        } else if (lower.contains("invalid email or password") || lower.contains("bad credentials")) {
            code = ErrorCode.UNAUTHORIZED;
        } else if (lower.contains("not found")) {
            code = ErrorCode.RESOURCE_NOT_FOUND;
        } else {
            code = ErrorCode.BAD_REQUEST;
            // Untyped 400s are the ones most likely to be real bugs, so keep the stack trace.
            log.warn("Untyped RuntimeException at {}: {}", request.getRequestURI(), message, ex);
        }
        return build(code, message, request, null);
    }

    /** Last resort: anything not caught above becomes a 500 without leaking internals. */
    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> handleUnexpected(Exception ex, HttpServletRequest request) {
        log.error("Unhandled exception at {}", request.getRequestURI(), ex);
        return build(ErrorCode.INTERNAL_ERROR,
                "Something went wrong on our side. Please try again, or contact support if it persists.",
                request, null);
    }

    private ResponseEntity<ErrorResponse> build(ErrorCode code, String message,
                                                HttpServletRequest request, Map<String, Object> details) {
        HttpStatus status = code.getStatus();
        String path = request != null ? request.getRequestURI() : null;
        return ResponseEntity.status(status).body(new ErrorResponse(code, message, path, details));
    }
}
