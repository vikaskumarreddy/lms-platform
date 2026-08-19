package com.institute.lms.config;

import com.institute.lms.interceptor.SubscriptionStateInterceptor;
import com.institute.lms.interceptor.TenantInterceptor;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * Registers the request interceptors, in the order they must run.
 *
 * <p>{@link TenantInterceptor} runs first and resolves which organization the request
 * belongs to (from the JWT, {@code X-Tenant-ID}, {@code X-Tenant-Slug} or hostname).
 * {@link SubscriptionStateInterceptor} runs second and needs that context to be present
 * — it cannot judge a subscription before it knows whose subscription it is. The
 * explicit {@code order(...)} calls make that dependency a guarantee rather than a
 * side effect of registration sequence.
 *
 * <p><b>Important:</b> {@code /api/auth/**} (login/register) is intentionally INCLUDED
 * for the tenant interceptor so the tenant is resolved before {@code AuthService} looks
 * the user up — otherwise login can never scope its lookup to the correct organization
 * and always falls back to the first globally-matching account.
 */
@Configuration
public class WebConfig implements WebMvcConfigurer {

    /** Endpoints that are not tenant-scoped at all. */
    private static final String[] INFRASTRUCTURE_PATHS = {
            "/api/system-config/public/**",
            "/v3/api-docs/**",
            "/swagger-ui.html",
            "/swagger-ui/**",
            "/api-docs/**",
            "/actuator/**"
    };

    private final TenantInterceptor tenantInterceptor;
    private final SubscriptionStateInterceptor subscriptionStateInterceptor;

    public WebConfig(TenantInterceptor tenantInterceptor,
                     SubscriptionStateInterceptor subscriptionStateInterceptor) {
        this.tenantInterceptor = tenantInterceptor;
        this.subscriptionStateInterceptor = subscriptionStateInterceptor;
    }

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(tenantInterceptor)
                .order(0)
                .excludePathPatterns(INFRASTRUCTURE_PATHS);

        registry.addInterceptor(subscriptionStateInterceptor)
                .order(1)
                .excludePathPatterns(INFRASTRUCTURE_PATHS);
    }
}
