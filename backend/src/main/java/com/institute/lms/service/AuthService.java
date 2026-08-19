package com.institute.lms.service;

import com.institute.lms.dto.auth.AuthResponse;
import com.institute.lms.dto.auth.LoginRequest;
import com.institute.lms.dto.auth.RegisterRequest;
import com.institute.lms.entity.Organization;
import com.institute.lms.entity.User;
import com.institute.lms.repository.OrganizationRepository;
import com.institute.lms.repository.UserRepository;
import com.institute.lms.security.JwtService;
import com.institute.lms.service.subscription.ActivityMeterService;
import com.institute.lms.util.OrganizationContext;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;

    @Value("${jwt.expiration}")
    private long jwtExpiration;

        private final OrganizationRepository organizationRepository;
        private final OrganizationContext organizationContext;
        private final ActivityMeterService activityMeter;

    public AuthService(UserRepository userRepository, PasswordEncoder passwordEncoder, JwtService jwtService,
                         OrganizationRepository organizationRepository, OrganizationContext organizationContext,
                         ActivityMeterService activityMeter) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
        this.organizationRepository = organizationRepository;
        this.organizationContext = organizationContext;
        this.activityMeter = activityMeter;
    }

    public AuthResponse login(LoginRequest request) {
        User user = resolveUserForLogin(request.getEmail());
        if (user == null) {
            throw new RuntimeException("Invalid email or password");
        }

        if (!passwordEncoder.matches(request.getPassword(), user.getPassword())) {
            throw new RuntimeException("Invalid email or password");
        }

        if (!Boolean.TRUE.equals(user.getIsActive())) {
            throw new RuntimeException("Account disabled");
        }

        // Update last login
        user.setLastLogin(LocalDateTime.now());
        userRepository.save(user);

        // Signing in makes a student billable for this month. Recorded here rather than
        // relying on last_login, which is overwritten on every sign-in and so cannot
        // answer "was this student active in July" once August arrives.
        //
        // The meter never throws and runs in its own transaction, so a metering problem
        // cannot stop someone logging in — deliberately, because losing one metering row
        // costs a fraction of a rupee while a failed login during an exam does not.
        if (user.getRole() == User.UserRole.STUDENT) {
            activityMeter.recordLogin(user.getOrganizationId(), user.getId());
        }

        return buildAuthResponse(user);
    }

    /** Resolves the login user scoped to the current tenant (from the domain/JWT context),
     *  falling back to the platform standard account when no tenant context is available. */
    private User resolveUserForLogin(String email) {
        Long tenantOrgId = organizationContext.getCurrentOrgId();
        if (tenantOrgId != null) {
            var inTenant = userRepository.findByOrganizationIdAndEmail(tenantOrgId, email);
            if (inTenant.isPresent()) {
                return inTenant.get();
            }
        }
        // Legacy fallback for the main platform account (admin@axisora.com in axisora org)
        // and situations without a resolvable tenant (e.g. the platform super admin logging
        // in at placements.com). findAnyByEmail is a NATIVE query so it is NOT scoped by the
        // @TenantId discriminator (which would otherwise filter to the "-1" no-tenant sentinel
        // and return nothing, making the super admin unable to log in).
        return userRepository.findAnyByEmail(email).orElse(null);
    }

    public AuthResponse register(RegisterRequest request) {
        // Resolve the target organization first: explicit request field wins, then the
        // tenant resolved by TenantInterceptor for this request (JWT/header/subdomain),
        // falling back to the default "axisora" org only when neither is available.
        Long targetOrgId = request.getOrganizationId();
        if (targetOrgId == null) {
            targetOrgId = organizationContext.getCurrentOrgId();
        }
        if (targetOrgId == null) {
            targetOrgId = organizationRepository.findBySlug("axisora").map(Organization::getId).orElse(null);
        }

        // Email uniqueness is scoped per-organization (see V28's uk_users_org_email),
        // so check within the target org rather than globally.
        if (targetOrgId != null
                ? userRepository.existsByOrganizationIdAndEmail(targetOrgId, request.getEmail())
                : userRepository.existsByEmail(request.getEmail())) {
            throw new RuntimeException("Email already registered");
        }

        User user = new User();
        user.setName(request.getName());
        user.setEmail(request.getEmail());
        user.setPassword(passwordEncoder.encode(request.getPassword()));
        user.setPhone(request.getPhone());

        // Default role is STUDENT unless specified
        String roleStr = request.getRole() != null ? request.getRole().toUpperCase() : "STUDENT";
        User.UserRole role;
        try {
            role = User.UserRole.valueOf(roleStr);
        } catch (IllegalArgumentException e) {
            role = User.UserRole.STUDENT;
        }
        user.setRole(role);
        user.setIsActive(true);
        user.setIsEmailVerified(false);
        user.setOrganizationId(targetOrgId);

        userRepository.save(user);

        return buildAuthResponse(user);
    }

        private AuthResponse buildAuthResponse(User user) {
        // Build JWT with organization_id claim for tenant resolution
        Map<String, Object> extraClaims = new HashMap<>();
        if (user.getOrganizationId() != null) {
            extraClaims.put("organization_id", user.getOrganizationId());
        }
        // Included so TenantInterceptor can bypass tenant scoping for platform
        // super-admins (ADMIN role), who need to see across every organization.
        if (user.getRole() != null) {
            extraClaims.put("role", user.getRole().name());
        }
        String accessToken = jwtService.generateToken(extraClaims, user);
        String refreshToken = jwtService.generateRefreshToken(user);
        String roleName = user.getRole() != null ? user.getRole().name() : "STUDENT";

        return AuthResponse.builder()
                .accessToken(accessToken)
                .refreshToken(refreshToken)
                .tokenType("Bearer")
                .expiresIn(jwtExpiration)
                .user(AuthResponse.UserInfo.builder()
                        .id(user.getId())
                        .email(user.getEmail())
                        .fullName(user.getName())
                        .role(roleName)
                        .roles(List.of(roleName))
                        .planId(user.getPlanId())
                        .batchId(user.getBatchId())
                        .organizationId(user.getOrganizationId())
                        .build())
                .build();
    }
}