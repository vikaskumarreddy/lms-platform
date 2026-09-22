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
import com.institute.lms.entity.StudentPaymentInfo;
import java.util.Optional;
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
    private final StudentPaymentService studentPaymentService;

    public AuthService(UserRepository userRepository, PasswordEncoder passwordEncoder, JwtService jwtService,
                         OrganizationRepository organizationRepository, OrganizationContext organizationContext,
                         ActivityMeterService activityMeter, StudentPaymentService studentPaymentService) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
        this.organizationRepository = organizationRepository;
        this.organizationContext = organizationContext;
        this.activityMeter = activityMeter;
        this.studentPaymentService = studentPaymentService;
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
        // No match in the resolved tenant (or no tenant resolvable at all, e.g. the platform
        // super admin logging in at placements.com). Look up every organization sharing this
        // email instead of blindly grabbing the lowest id: that used to silently authenticate
        // the caller into whichever org happened to register the email first (the ghost admin
        // admin@axisora.com exists in every org, so this was hit constantly), which was the
        // root cause of the org-isolation regression. Disambiguate explicitly instead.
        List<User> matches = userRepository.findAllByEmailAcrossOrgs(email);
        if (matches.isEmpty()) {
            return null;
        }
        if (matches.size() == 1) {
            return matches.get(0);
        }
        throw new RuntimeException(
                "This email exists in multiple organizations. Select the correct organization before signing in.");
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

        // Public self-registration can only ever create STUDENT accounts.
        // Administrative roles (ADMIN, INSTITUTE_ADMIN, INSTRUCTOR) must be provisioned
        // by authorized administrators via the admin portal.
        user.setRole(User.UserRole.STUDENT);
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
        // Lets JwtAuthenticationFilter resolve the current user unambiguously by primary
        // key instead of by email, which is NOT globally unique (the ghost platform admin
        // admin@axisora.com exists in every organization) and previously caused every
        // request to silently resolve to whichever org created that email first.
        extraClaims.put("user_id", user.getId());
        String accessToken = jwtService.generateToken(extraClaims, user);
        String refreshToken = jwtService.generateRefreshToken(user);
        String roleName = user.getRole() != null ? user.getRole().name() : "STUDENT";

        // Payment info for students
        AuthResponse.UserInfo.UserInfoBuilder userInfoBuilder = AuthResponse.UserInfo.builder()
                .id(user.getId())
                .email(user.getEmail())
                .fullName(user.getName())
                .role(roleName)
                .roles(List.of(roleName))
                .planId(user.getPlanId())
                .batchId(user.getBatchId())
                .organizationId(user.getOrganizationId());

        if (user.getRole() == User.UserRole.STUDENT && user.getOrganizationId() != null) {
            Optional<StudentPaymentInfo> paymentInfo = studentPaymentService.getPaymentInfo(user.getId(), user.getOrganizationId());
            if (paymentInfo.isPresent()) {
                var info = paymentInfo.get();
                userInfoBuilder.paymentRequired(info.isPaymentDue());
                userInfoBuilder.paymentMethod(info.getPaymentMethod());
                userInfoBuilder.paymentStatus(info.getPaymentStatus());
                userInfoBuilder.amountDue(info.getAmountDue());
            } else {
                // No StudentPaymentInfo row exists for this student at all -- payment
                // method/amount only ever live on that row (created by
                // StudentPaymentService.createPaymentForNewStudent at enrollment time),
                // never on the User entity itself. Its absence means the student was
                // enrolled without an enrollment fee, so there's nothing to collect.
                userInfoBuilder.paymentRequired(false);
                userInfoBuilder.paymentMethod("CASH");
                userInfoBuilder.paymentStatus("COMPLETED");
            }
        }

        return AuthResponse.builder()
                .accessToken(accessToken)
                .refreshToken(refreshToken)
                .tokenType("Bearer")
                .expiresIn(jwtExpiration)
                .user(userInfoBuilder.build())
                .build();
    }

    /**
     * Logout the current user. Since JWTs are stateless, this is primarily
     * a hook for future token blacklisting. The client is responsible for
     * clearing its stored tokens.
     */
    public void logout() {
        // Stateless JWT: no server-side invalidation needed.
        // This method exists as a hook for future token blacklisting.
        // The client must clear its own stored tokens.
    }
}