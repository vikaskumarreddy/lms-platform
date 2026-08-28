package com.institute.lms.service;

import com.institute.lms.dto.user.StudentRequest;
import com.institute.lms.dto.user.StudentResponse;
import com.institute.lms.entity.Batch;
import com.institute.lms.entity.StudentPlacement;
import com.institute.lms.entity.SubscriptionPlan;
import com.institute.lms.entity.User;
import com.institute.lms.repository.BatchRepository;
import com.institute.lms.repository.StudentPlacementRepository;
import com.institute.lms.repository.SubscriptionPlanRepository;
import com.institute.lms.repository.UserRepository;
import com.institute.lms.util.OrganizationContext;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;
import com.institute.lms.entity.StudentPaymentInfo;

@Service
public class UserService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final StudentPlacementRepository placementRepository;
    private final SubscriptionPlanRepository subscriptionPlanRepository;
    private final BatchRepository batchRepository;
    private final OrganizationContext organizationContext;

    private final StudentPaymentService studentPaymentService;

    public UserService(UserRepository userRepository, PasswordEncoder passwordEncoder,
                       StudentPlacementRepository placementRepository, SubscriptionPlanRepository subscriptionPlanRepository,
                       BatchRepository batchRepository, OrganizationContext organizationContext,
                       StudentPaymentService studentPaymentService) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.placementRepository = placementRepository;
        this.subscriptionPlanRepository = subscriptionPlanRepository;
        this.batchRepository = batchRepository;
        this.organizationContext = organizationContext;
        this.studentPaymentService = studentPaymentService;
    }


    public List<StudentResponse> getAllStudents() {
        return userRepository.findByRole(User.UserRole.STUDENT)
                .stream()
                .map(this::toResponse)
                .collect(Collectors.toList());
    }

    public Optional<StudentResponse> getStudentById(Long id) {
        return userRepository.findById(id)
                .filter(user -> user.getRole() == User.UserRole.STUDENT)
                .map(this::toResponse);
    }

    public Optional<StudentResponse> getStudentByEmail(String email) {
        return userRepository.findByEmail(email)
                .filter(user -> user.getRole() == User.UserRole.STUDENT)
                .map(this::toResponse);
    }

    @Transactional
    public StudentResponse createStudent(StudentRequest request) {
        if (userRepository.existsByEmail(request.getEmail())) {
            throw new RuntimeException("Email already registered");
        }
        if (request.getPhone() != null && !request.getPhone().isEmpty() && userRepository.existsByPhone(request.getPhone())) {
            throw new RuntimeException("Phone already registered");
        }
        if (request.getUsername() != null && !request.getUsername().isEmpty() && userRepository.existsByUsername(request.getUsername())) {
            throw new RuntimeException("Username already taken");
        }

        Long orgId = organizationContext.getCurrentOrgId();
        if (orgId == null) {
            throw new RuntimeException("No organization context set");
        }

        // If no plan is explicitly provided but a batch is assigned, inherit the plan from the batch
        Long effectivePlanId = request.getPlanId();
        if (effectivePlanId == null && request.getBatchId() != null) {
            Batch batch = batchRepository.findById(request.getBatchId())
                    .orElse(null);
            if (batch != null && batch.getPlanId() != null) {
                effectivePlanId = batch.getPlanId();
            }
        }

        User user = new User();
        user.setName(request.getName());
        user.setEmail(request.getEmail());
        user.setPassword(passwordEncoder.encode(request.getPassword() != null && !request.getPassword().isEmpty()
                ? request.getPassword() : "student123"));
        user.setPhone(request.getPhone());
        user.setUsername(request.getUsername());
        user.setRole(User.UserRole.STUDENT);
        user.setIsActive(request.getIsActive() != null ? request.getIsActive() : true);
        user.setIsEmailVerified(false);
        user.setPlanId(effectivePlanId);
        user.setBatchId(request.getBatchId());
        user.setOrganizationId(orgId);
        user.setLinkedin(request.getLinkedin());
        user.setGithub(request.getGithub());
        user.setParentName(request.getParentName());
        user.setParentPhone(request.getParentPhone());
        user.setParentEmail(request.getParentEmail());
        user.setNotifyMedium(parseNotifyMedium(request.getNotifyMedium()));

        User savedUser = userRepository.save(user);

        // Create payment record based on payment method selection
        String paymentMethod = request.getPaymentMethod();
        if (paymentMethod == null || paymentMethod.isEmpty()) {
            paymentMethod = "CASH"; // default to cash
        }
        try {
            studentPaymentService.createPaymentForNewStudent(savedUser.getId(), orgId, paymentMethod);
        } catch (Exception e) {
            // Log but don't fail - payment creation is best-effort
            System.err.println("Warning: Failed to create payment record for student: " + e.getMessage());
        }

        return toResponse(savedUser);
    }

    @Transactional
    public Optional<StudentResponse> updateStudent(Long id, StudentRequest request) {
        Optional<User> userOpt = userRepository.findById(id);
        if (userOpt.isEmpty() || userOpt.get().getRole() != User.UserRole.STUDENT) {
            return Optional.empty();
        }

        User user = userOpt.get();
        user.setName(request.getName());
        user.setEmail(request.getEmail());
        user.setPhone(request.getPhone());
        user.setUsername(request.getUsername());
        if (request.getPassword() != null && !request.getPassword().isEmpty()) {
            user.setPassword(passwordEncoder.encode(request.getPassword()));
        }
        if (request.getIsActive() != null) {
            user.setIsActive(request.getIsActive());
        }
        // planId/batchId: the admin portal always sends these explicitly (including null
        // to intentionally clear a batch/plan), so we keep straightforward assignment here.
        // The mobile app's self-service profile update instead merges in the student's
        // current planId/batchId before calling this endpoint (see ApiService.updateUserProfile)
        // so it never accidentally wipes these out.
        user.setPlanId(request.getPlanId());
        user.setBatchId(request.getBatchId());
        user.setLinkedin(request.getLinkedin());
        user.setGithub(request.getGithub());
        user.setParentName(request.getParentName());
        user.setParentPhone(request.getParentPhone());
        user.setParentEmail(request.getParentEmail());
        if (request.getNotifyMedium() != null && !request.getNotifyMedium().isBlank()) {
            user.setNotifyMedium(parseNotifyMedium(request.getNotifyMedium()));
        }

        return Optional.of(toResponse(userRepository.save(user)));
    }

    /** Parses a notify-medium string, defaulting to PUSH for blank/unknown values rather than failing the request. */
    private com.institute.lms.entity.NotifyMedium parseNotifyMedium(String value) {
        if (value == null || value.isBlank()) return com.institute.lms.entity.NotifyMedium.PUSH;
        try {
            return com.institute.lms.entity.NotifyMedium.valueOf(value.trim().toUpperCase());
        } catch (IllegalArgumentException e) {
            return com.institute.lms.entity.NotifyMedium.PUSH;
        }
    }

    @Transactional
    public boolean updateFcmToken(Long id, String fcmToken) {
        Optional<User> userOpt = userRepository.findById(id);
        if (userOpt.isEmpty()) return false;
        User user = userOpt.get();
        user.setFcmToken(fcmToken);
        userRepository.save(user);
        return true;
    }

    @Transactional
    public boolean deleteStudent(Long id) {
        Optional<User> userOpt = userRepository.findById(id);
        if (userOpt.isEmpty() || userOpt.get().getRole() != User.UserRole.STUDENT) {
            return false;
        }
        userRepository.delete(userOpt.get());
        return true;
    }

    public StudentResponse toResponse(User user) {
        StudentResponse response = new StudentResponse(
                user.getId(),
                user.getName(),
                user.getEmail(),
                user.getPhone(),
                user.getUsername(),
                user.getRole() != null ? user.getRole().name() : "STUDENT",
                user.getIsActive(),
                user.getIsEmailVerified(),
                user.getPlanId(),
                user.getBatchId(),
                user.getCreatedAt(),
                user.getLastLogin(),
                user.getLinkedin(),
                user.getGithub(),
                user.getParentName(),
                user.getParentPhone(),
                user.getParentEmail(),
                user.getNotifyMedium() != null ? user.getNotifyMedium().name() : "PUSH",
                null, null, null, null, null, null, null, null,
                null, null, null
        );
        
        // Add batch details
        if (user.getBatchId() != null) {
            Optional<Batch> batchOpt = batchRepository.findById(user.getBatchId());
            if (batchOpt.isPresent()) {
                response.setBatchName(batchOpt.get().getName());
            }
        }
        
        // Add subscription plan details
        if (user.getPlanId() != null) {
            Optional<SubscriptionPlan> planOpt = subscriptionPlanRepository.findById(user.getPlanId());
            if (planOpt.isPresent()) {
                SubscriptionPlan plan = planOpt.get();
                response.setPlanName(plan.getName());
                response.setPlanPrice(plan.getPrice() != null ? plan.getPrice().doubleValue() : null);
                response.setPlanPeriod(plan.getPeriod());
            }
        }
        
        // Add placement details
        Optional<StudentPlacement> placementOpt = placementRepository.findByUserIdAndIsPlacedTrue(user.getId());
        if (placementOpt.isPresent()) {
            StudentPlacement placement = placementOpt.get();
            response.setIsPlaced(true);
            response.setPlacedCompany(placement.getCompanyName());
            response.setPlacedRole(placement.getRole());
            response.setPlacedPackage(placement.getPackageAmount());
        } else {
            response.setIsPlaced(false);
        }

        // Enrollment fee state. Students created before this feature have no row,
        // which reads as CASH — they already have access and must not be gated.
        studentPaymentService.getPaymentInfo(user.getId(), user.getOrganizationId())
                .ifPresentOrElse(info -> {
                    response.setPaymentMethod(info.getPaymentMethod());
                    response.setPaymentStatus(info.getPaymentStatus());
                    response.setAmountDue(info.getAmountDue());
                }, () -> {
                    response.setPaymentMethod("CASH");
                    response.setPaymentStatus("COMPLETED");
                });

        return response;
    }

    // ============= Organization-Scoped Methods =============

    /**
     * Gets all faculty users in the current organization.
     * Used by org admins to manage faculty.
     */
    public List<StudentResponse> getFacultyInCurrentOrganization() {
        Long orgId = organizationContext.getCurrentOrgId();
        if (orgId == null) {
            throw new RuntimeException("No organization context set");
        }
        return userRepository.findByOrganizationIdAndRole(orgId, User.UserRole.INSTRUCTOR)
                .stream()
                .map(this::toResponse)
                .collect(Collectors.toList());
    }

    /**
     * Gets all students in the current organization.
     * Used by org admins to manage students.
     */
    public List<StudentResponse> getStudentsInCurrentOrganization() {
        Long orgId = organizationContext.getCurrentOrgId();
        if (orgId == null) {
            throw new RuntimeException("No organization context set");
        }
        return userRepository.findByOrganizationIdAndRole(orgId, User.UserRole.STUDENT)
                .stream()
                .map(this::toResponse)
                .collect(Collectors.toList());
    }

    /**
     * Gets all active users in the current organization.
     */
    public List<StudentResponse> getActiveUsersInCurrentOrganization() {
        Long orgId = organizationContext.getCurrentOrgId();
        if (orgId == null) {
            throw new RuntimeException("No organization context set");
        }
        return userRepository.findByOrganizationIdAndIsActive(orgId, true)
                .stream()
                .map(this::toResponse)
                .collect(Collectors.toList());
    }

    /**
     * Creates a new user in the current organization.
     */
    public User createUserInCurrentOrganization(String email, String name, String password,
                                                String phone, User.UserRole role) {
        Long orgId = organizationContext.getCurrentOrgId();
        if (orgId == null) {
            throw new RuntimeException("No organization context set");
        }

        if (userRepository.existsByEmail(email)) {
            throw new RuntimeException("Email already registered");
        }

        User user = new User();
        user.setEmail(email);
        user.setName(name);
        user.setPassword(passwordEncoder.encode(password != null ? password : "default123"));
        user.setPhone(phone);
        user.setRole(role);
        user.setIsActive(true);
        user.setIsEmailVerified(false);
        user.setOrganizationId(orgId);

        return userRepository.save(user);
    }

    /**
     * Creates an organization admin (INSTITUTE_ADMIN) in the current organization.
     */
    public User createOrgAdminInCurrentOrganization(String email, String name, String password, String phone) {
        return createUserInCurrentOrganization(email, name, password, phone, User.UserRole.INSTITUTE_ADMIN);
    }

    /**
     * Creates a faculty user in the current organization.
     */
    public User createFacultyInCurrentOrganization(String email, String name, String password, String phone) {
        return createUserInCurrentOrganization(email, name, password, phone, User.UserRole.INSTRUCTOR);
    }

    /**
     * Creates a student user in the current organization.
     */
    public User createStudentInCurrentOrganization(String email, String name, String password, String phone) {
        return createUserInCurrentOrganization(email, name, password, phone, User.UserRole.STUDENT);
    }
}
