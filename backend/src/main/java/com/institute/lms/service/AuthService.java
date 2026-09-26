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
import com.institute.lms.exception.UnauthorizedException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import com.institute.lms.entity.SubscriptionPlan;
import com.institute.lms.repository.SubscriptionPlanRepository;

import java.time.LocalDateTime;
import com.institute.lms.entity.StudentPaymentInfo;
import java.util.Optional;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
public class AuthService {

    private static final Logger log = LoggerFactory.getLogger(AuthService.class);

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;

    @Value("${jwt.expiration}")
    private long jwtExpiration;

    private final OrganizationRepository organizationRepository;
    private final OrganizationContext organizationContext;
    private final ActivityMeterService activityMeter;
    private final StudentPaymentService studentPaymentService;
    private final BatchRuleService batchRuleService;
    private final SubscriptionPlanRepository subscriptionPlanRepository;

    public AuthService(UserRepository userRepository, PasswordEncoder passwordEncoder, JwtService jwtService,
                         OrganizationRepository organizationRepository, OrganizationContext organizationContext,
                         ActivityMeterService activityMeter, StudentPaymentService studentPaymentService,
                         BatchRuleService batchRuleService, SubscriptionPlanRepository subscriptionPlanRepository) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
        this.organizationRepository = organizationRepository;
        this.organizationContext = organizationContext;
        this.activityMeter = activityMeter;
        this.studentPaymentService = studentPaymentService;
        this.batchRuleService = batchRuleService;
        this.subscriptionPlanRepository = subscriptionPlanRepository;
    }


    public AuthResponse login(LoginRequest request) {
        String email = request.getEmail() != null ? request.getEmail().trim().toLowerCase() : "";
        User user = resolveUserForLogin(email);
        if (user == null) {
            throw new UnauthorizedException("Invalid email or password");
        }

        if (!passwordEncoder.matches(request.getPassword(), user.getPassword())) {
            throw new UnauthorizedException("Invalid email or password");
        }

        if (!Boolean.TRUE.equals(user.getIsActive())) {
            // Check if this is an unpaid online-enrolled student whose account is pending payment
            if (user.getRole() == User.UserRole.STUDENT && user.getOrganizationId() != null) {
                Optional<StudentPaymentInfo> paymentInfo = studentPaymentService.getPaymentInfo(user.getId(), user.getOrganizationId());
                if (paymentInfo.isPresent() && "ONLINE".equalsIgnoreCase(paymentInfo.get().getPaymentMethod())
                        && !"COMPLETED".equalsIgnoreCase(paymentInfo.get().getPaymentStatus())) {
                    // Allow login strictly into payment mode: Flutter redirects directly to vendor checkout
                    return buildAuthResponseWithPendingPayment(user, paymentInfo.get());
                }
            }
            throw UnauthorizedException.forbidden("Account disabled");
        }

        // Update last login timestamp safely via native SQL (avoids @Version optimistic lock contention)
        try {
            userRepository.updateLastLogin(user.getId(), LocalDateTime.now());
        } catch (Exception e) {
            log.warn("Failed to update last login timestamp for user {}: {}", user.getId(), e.getMessage());
        }

        // Signing in makes a student billable for this month. Recorded here rather than
        // relying on last_login, which is overwritten on every sign-in and so cannot
        // answer "was this student active in July" once August arrives.
        if (user.getRole() == User.UserRole.STUDENT) {
            activityMeter.recordLogin(user.getOrganizationId(), user.getId());
        }

        return buildAuthResponse(user);
    }

    /** Resolves the login user scoped strictly to the current tenant (from domain or X-Tenant-Slug header),
     *  preventing cross-organization logins and ghost admin access on tenant portals. */
    private User resolveUserForLogin(String email) {
        Long tenantOrgId = organizationContext.getCurrentOrgId();
        if (tenantOrgId != null) {
            var inTenant = userRepository.findNonGhostByOrgIdAndEmail(tenantOrgId, email);
            if (inTenant.isPresent()) {
                return inTenant.get();
            }
            // User does not exist in this organization. Check if they belong to another organization.
            List<User> otherMatches = userRepository.findAllNonGhostByEmailAcrossOrgs(email);
            if (!otherMatches.isEmpty()) {
                User other = otherMatches.get(0);
                if (other.getRole() == User.UserRole.ADMIN) {
                    throw UnauthorizedException.forbidden(
                            "Platform administrator accounts must sign in through the platform portal (admin.axisoraforge.in).");
                }
                Long otherOrgId = other.getOrganizationId();
                String targetPortal = "";
                if (otherOrgId != null) {
                    targetPortal = organizationRepository.findById(otherOrgId)
                            .map(org -> {
                                String s = org.getSlug();
                                if ("admin".equalsIgnoreCase(s) || "axisora".equalsIgnoreCase(s)) {
                                    return " (admin.axisoraforge.in)";
                                }
                                return " (" + s + ".axisoraforge.in)";
                            })
                            .orElse("");
                }
                throw UnauthorizedException.forbidden(
                        "This account belongs to another organization. Please sign in through your organization's portal" + targetPortal + ".");
            }
            return null; // Will trigger standard 401 "Invalid email or password"
        }

        // No tenant context was resolvable (e.g. root domain)
        List<User> matches = userRepository.findAllNonGhostByEmailAcrossOrgs(email);
        if (matches.isEmpty()) {
            return null;
        }
        if (matches.size() == 1) {
            User match = matches.get(0);
            if (match.getRole() == User.UserRole.ADMIN) {
                return match;
            }
            // Users belonging to the default/platform organization (org 1) can sign in on the platform domain
            if (match.getOrganizationId() != null && match.getOrganizationId().equals(1L)) {
                return match;
            }
            Long orgId = match.getOrganizationId();
            String portal = orgId != null
                    ? organizationRepository.findById(orgId).map(org -> {
                        String s = org.getSlug();
                        if ("admin".equalsIgnoreCase(s) || "axisora".equalsIgnoreCase(s)) {
                            return "admin.axisoraforge.in";
                        }
                        return s + ".axisoraforge.in";
                    }).orElse("your organization domain")
                    : "your organization domain";
            throw UnauthorizedException.forbidden("Please sign in through your organization's portal (" + portal + ").");
        }
        throw UnauthorizedException.forbidden(
                "This email exists in multiple organizations. Please sign in through your organization's specific domain (e.g. your-subdomain.axisoraforge.in).");
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
        Long planId = request.getPlanId();
        if (planId == null && request.getCustomFields() != null) {
            Object pVal = request.getCustomFields().get("planId");
            if (pVal instanceof Number) {
                planId = ((Number) pVal).longValue();
            } else if (pVal != null) {
                try {
                    planId = Long.parseLong(pVal.toString().trim());
                } catch (Exception ignored) {}
            }
        }

        // Match with original subscription plan
        if (planId != null) {
            final Long pid = planId;
            Optional<SubscriptionPlan> planOpt = subscriptionPlanRepository.findById(pid)
                    .or(() -> subscriptionPlanRepository.findAnyById(pid));
            if (planOpt.isPresent()) {
                user.setPlanId(planOpt.get().getId());
            } else {
                user.setPlanId(planId);
            }
        } else if (request.getCustomFields() != null && request.getCustomFields().get("planName") != null) {
            String pName = request.getCustomFields().get("planName").toString().trim();
            try {
                List<SubscriptionPlan> activePlans = subscriptionPlanRepository.findAllActivePlansNative();
                for (SubscriptionPlan sp : activePlans) {
                    if (sp.getName().equalsIgnoreCase(pName)) {
                        user.setPlanId(sp.getId());
                        break;
                    }
                }
            } catch (Exception ignored) {}
        }

        user.setLinkedin(request.getLinkedin());
        user.setGithub(request.getGithub());
        user.setParentName(request.getParentName());
        user.setParentPhone(request.getParentPhone());
        user.setParentEmail(request.getParentEmail());
        if (request.getNotifyMedium() != null && !request.getNotifyMedium().isBlank()) {
            try {
                user.setNotifyMedium(com.institute.lms.entity.NotifyMedium.valueOf(request.getNotifyMedium().toUpperCase()));
            } catch (Exception ignored) {}
        }

        // Serialize and save custom fields
        if (request.getCustomFields() != null && !request.getCustomFields().isEmpty()) {
            try {
                user.setCustomFields(new com.fasterxml.jackson.databind.ObjectMapper().writeValueAsString(request.getCustomFields()));
            } catch (Exception e) {
                System.err.println("Could not serialize custom_fields: " + e.getMessage());
            }
        }

        // Evaluate batch rules based on subscription plan and submitted fields
        if (targetOrgId != null && user.getPlanId() != null) {
            try {
                Map<String, Object> evalData = new HashMap<>();
                if (request.getCustomFields() != null) {
                    evalData.putAll(request.getCustomFields());
                }
                evalData.put("name", request.getName());
                evalData.put("email", request.getEmail());
                evalData.put("phone", request.getPhone());
                evalData.put("planId", user.getPlanId());
                evalData.put("linkedin", request.getLinkedin());
                evalData.put("github", request.getGithub());
                evalData.put("parentName", request.getParentName());
                evalData.put("parentPhone", request.getParentPhone());
                evalData.put("parentEmail", request.getParentEmail());
                evalData.put("notifyMedium", request.getNotifyMedium());

                Long matchedBatchId = batchRuleService.resolveMatchingBatch(targetOrgId, user.getPlanId(), evalData);
                if (matchedBatchId != null) {
                    user.setBatchId(matchedBatchId);
                }
            } catch (Exception e) {
                System.err.println("Error evaluating batch rules on registration: " + e.getMessage());
            }
        }

        String paymentMethod = request.getPaymentMethod();

        if (paymentMethod == null || paymentMethod.isBlank()) {
            paymentMethod = "ONLINE";
        }

        // Public self-registration can only ever create STUDENT accounts.
        // Administrative roles (ADMIN, INSTITUTE_ADMIN, INSTRUCTOR) must be provisioned
        // by authorized administrators via the admin portal.
        user.setRole(User.UserRole.STUDENT);
        if ("ONLINE".equalsIgnoreCase(paymentMethod)) {
            // Access withheld until payment is completed and verified
            user.setIsActive(false);
        } else {
            user.setIsActive(true);
        }
        user.setIsEmailVerified(false);
        user.setOrganizationId(targetOrgId);

        User savedUser = userRepository.save(user);

        if (targetOrgId != null) {
            try {
                studentPaymentService.createPaymentForNewStudent(savedUser.getId(), targetOrgId, paymentMethod);
            } catch (Exception e) {
                // Log warning but don't fail registration
                System.err.println("Failed to create student payment info on registration: " + e.getMessage());
            }
        }

        if ("ONLINE".equalsIgnoreCase(paymentMethod) && targetOrgId != null) {
            Optional<StudentPaymentInfo> paymentInfo = studentPaymentService.getPaymentInfo(savedUser.getId(), targetOrgId);
            if (paymentInfo.isPresent() && paymentInfo.get().isPaymentDue()) {
                return buildAuthResponseWithPendingPayment(savedUser, paymentInfo.get());
            }
        }

        return buildAuthResponse(savedUser);
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

        String tenantSlug = null;
        String orgName = null;
        if (user.getOrganizationId() != null) {
            Optional<Organization> orgOpt = organizationRepository.findById(user.getOrganizationId());
            if (orgOpt.isPresent()) {
                tenantSlug = orgOpt.get().getSlug();
                orgName = orgOpt.get().getName();
            }
        }

        // Payment info for students
        AuthResponse.UserInfo.UserInfoBuilder userInfoBuilder = AuthResponse.UserInfo.builder()
                .id(user.getId())
                .email(user.getEmail())
                .fullName(user.getName())
                .role(roleName)
                .roles(List.of(roleName))
                .planId(user.getPlanId())
                .batchId(user.getBatchId())
                .organizationId(user.getOrganizationId())
                .tenantSlug(tenantSlug)
                .organizationName(orgName);

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

        String activeGateway = null;
        if (user.getRole() == User.UserRole.STUDENT && user.getOrganizationId() != null) {
            activeGateway = studentPaymentService.getActiveGatewayName(user.getOrganizationId());
        }

        return AuthResponse.builder()
                .accessToken(accessToken)
                .refreshToken(refreshToken)
                .tokenType("Bearer")
                .expiresIn(jwtExpiration)
                .user(userInfoBuilder.build())
                .gateway(activeGateway)
                .build();
    }

    private AuthResponse buildAuthResponseWithPendingPayment(User user, StudentPaymentInfo paymentInfo) {
        AuthResponse response = buildAuthResponse(user);
        if (user.getOrganizationId() != null) {
            String gateway = studentPaymentService.getActiveGatewayName(user.getOrganizationId());
            response.setGateway(gateway);
            try {
                Map<String, Object> order = studentPaymentService.createPaymentOrder(user.getId(), user.getOrganizationId());
                response.setPaymentOrder(order);
            } catch (Exception e) {
                // Non-fatal: PaymentScreen will re-invoke create-order if needed
            }
        }
        return response;
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