package com.institute.lms.config;

import com.institute.lms.interceptor.TenantInterceptor;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * Registers the {@link TenantInterceptor} to run on all requests except
 * non-tenant infrastructure endpoints (public system-config, Swagger, actuator).
 *
 * <p><b>Important:</b> {@code /api/auth/**} (login/register) is intentionally
 * INCLUDED so the interceptor resolves the tenant (from the JWT, X-Tenant-ID,
 * X-Tenant-Slug or hostname) before {@code AuthService} looks the user up —
 * otherwise login can never scope its lookup to the correct organization and
 * always falls back to the first globally-matching account.
 */
@Configuration
public class WebConfig implements WebMvcConfigurer {

    private final TenantInterceptor tenantInterceptor;

    public WebConfig(TenantInterceptor tenantInterceptor) {
        this.tenantInterceptor = tenantInterceptor;
    }

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(tenantInterceptor)
                .excludePathPatterns(
                        "/api/system-config/public/**",
                        "/v3/api-docs/**",
                        "/swagger-ui.html",
                        "/swagger-ui/**",
                        "/api-docs/**",
                        "/actuator/**"
                );
    }
}
