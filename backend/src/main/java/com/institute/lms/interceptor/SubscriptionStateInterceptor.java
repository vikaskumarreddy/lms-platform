package com.institute.lms.interceptor;

import com.institute.lms.exception.ErrorCode;
import com.institute.lms.exception.ErrorResponse;
import com.institute.lms.exception.SubscriptionInactiveException;
import com.institute.lms.service.subscription.EntitlementService;
import com.institute.lms.service.subscription.ResolvedEntitlements;
import com.institute.lms.subscription.SubscriptionStatus;
import com.institute.lms.util.OrganizationContext;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

import java.util.List;

/**
 * Enforces the tenant's subscription state on every request, after
 * {@link TenantInterceptor} has resolved which tenant it is.
 *
 * <p><strong>What this replaces.</strong> Previously an inactive organization simply got
 * no tenant context, so Hibernate's discriminator matched nothing and every query came
 * back empty. The administrator saw a portal with no students, no courses and no
 * explanation — indistinguishable from data loss. There was no way to tell them their
 * subscription had lapsed, and no way for them to do anything about it.
 *
 * <p><strong>Three access levels.</strong> Full access passes through. Read-only
 * (expired, past grace) permits GET but refuses writes with a 402 naming the renewal
 * path. Suspended or cancelled refuses everything outside the whitelist.
 *
 * <p><strong>The whitelist matters.</strong> Authentication, reading the current
 * organization, and the entire Account and billing surface stay reachable in every
 * state. A tenant locked out of the page that explains why they are locked out — and
 * that carries the button to fix it — would be an obviously self-defeating design.
 */
@Component
public class SubscriptionStateInterceptor implements HandlerInterceptor {

    private static final Logger log = LoggerFactory.getLogger(SubscriptionStateInterceptor.class);

    /**
     * Paths that remain reachable regardless of subscription state, so a lapsed tenant
     * can always log in, see what happened, and pay.
     */
    private static final List<String> ALWAYS_ALLOWED = List.of(
            "/api/auth",
            "/api/account",
            "/api/organizations/current",
            "/api/org-subscriptions",
            "/api/plan-addons",
            "/api/system-config",
            "/actuator",
            "/swagger-ui",
            "/v3/api-docs"
    );

    /** Methods treated as reads. */
    private static final List<String> READ_METHODS = List.of("GET", "HEAD", "OPTIONS");

    private final EntitlementService entitlementService;
    private final OrganizationContext organizationContext;
    private final ObjectMapper objectMapper;

    public SubscriptionStateInterceptor(EntitlementService entitlementService,
                                        OrganizationContext organizationContext) {
        this.entitlementService = entitlementService;
        this.organizationContext = organizationContext;
        // Own mapper: this writes the response directly rather than going through the
        // exception handler, and needs JavaTimeModule for the timestamp fields.
        this.objectMapper = new ObjectMapper().registerModule(new JavaTimeModule());
        this.objectMapper.disable(com.fasterxml.jackson.databind.SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);
    }

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler)
            throws Exception {

        Long orgId = organizationContext.getCurrentOrgId();
        if (orgId == null) {
            // No tenant context means either the platform super admin or an
            // unauthenticated request. Neither is governed by a tenant's plan.
            return true;
        }
        if (isWhitelisted(request.getRequestURI())) {
            return true;
        }

        ResolvedEntitlements resolved;
        try {
            resolved = entitlementService.resolve(orgId);
        } catch (Exception e) {
            // Fail open on a lookup error. Blocking every tenant because entitlement
            // resolution hiccuped would turn a minor fault into a total outage; the
            // per-action quota guards still apply.
            log.error("Could not resolve subscription state for organization {}; allowing the request.", orgId, e);
            return true;
        }

        // An organization with no subscription at all is left alone here. That is the
        // state of a tenant mid-setup, and blocking them would make an organization
        // unusable between creation and plan assignment. Individual creation paths still
        // refuse through QuotaGuard, which gives a far clearer message than a blanket 402.
        if (!resolved.hasSubscription()) {
            return true;
        }

        SubscriptionStatus status = resolved.getStatus();
        if (status == null || status.allowsWrites()) {
            return true;
        }

        boolean isRead = READ_METHODS.contains(request.getMethod().toUpperCase());
        if (isRead && status.allowsReads()) {
            // Read-only: let it through, and flag it so the UI can show the banner
            // without a separate round trip.
            response.setHeader("X-Subscription-Status", status.name());
            response.setHeader("X-Subscription-Read-Only", "true");
            return true;
        }

        SubscriptionInactiveException error = buildError(resolved, status);
        writeError(request, response, error);
        return false;
    }

    private SubscriptionInactiveException buildError(ResolvedEntitlements resolved, SubscriptionStatus status) {
        var instance = resolved.getInstance();
        return switch (status) {
            case SUSPENDED -> SubscriptionInactiveException.suspended(
                    instance != null ? instance.getSuspensionReason() : null);
            case CANCELLED -> SubscriptionInactiveException.cancelled(resolved.getPlanName());
            default -> SubscriptionInactiveException.readOnly(
                    resolved.getPlanName(), instance != null ? instance.getPeriodEnd() : null);
        };
    }

    /**
     * Writes the standard error envelope directly.
     *
     * <p>An interceptor returning false short-circuits before the handler, so
     * {@code GlobalExceptionHandler} never sees this — the envelope has to be produced
     * here to keep the response shape identical to every other error the API returns.
     */
    private void writeError(HttpServletRequest request, HttpServletResponse response,
                            SubscriptionInactiveException error) throws Exception {
        ErrorCode code = error.getCode();
        response.setStatus(code.getStatus().value());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding("UTF-8");
        response.setHeader("X-Subscription-Status", code.name());

        ErrorResponse body = new ErrorResponse(code, error.getMessage(),
                request.getRequestURI(), error.getDetails());
        objectMapper.writeValue(response.getWriter(), body);
    }

    private boolean isWhitelisted(String uri) {
        if (uri == null) {
            return false;
        }
        for (String prefix : ALWAYS_ALLOWED) {
            if (uri.startsWith(prefix)) {
                return true;
            }
        }
        return false;
    }
}
