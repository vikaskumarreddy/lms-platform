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
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

@Service
public class UserService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final StudentPlacementRepository placementRepository;
    private final SubscriptionPlanRepository subscriptionPlanRepository;
    private final BatchRepository batchRepository;

    public UserService(UserRepository userRepository, PasswordEncoder passwordEncoder,
                       StudentPlacementRepository placementRepository, SubscriptionPlanRepository subscriptionPlanRepository,
                       BatchRepository batchRepository) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.placementRepository = placementRepository;
        this.subscriptionPlanRepository = subscriptionPlanRepository;
        this.batchRepository = batchRepository;
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
        user.setPlanId(request.getPlanId());
        user.setBatchId(request.getBatchId());
        user.setLinkedin(request.getLinkedin());
        user.setGithub(request.getGithub());

        return toResponse(userRepository.save(user));
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

        return Optional.of(toResponse(userRepository.save(user)));
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
                null, null, null, null, null, null, null, null
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
        
        return response;
    }
}