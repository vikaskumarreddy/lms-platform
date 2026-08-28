package com.institute.lms.controller;

import com.institute.lms.dto.user.StudentRequest;
import com.institute.lms.dto.user.StudentResponse;
import com.institute.lms.entity.User;
import com.institute.lms.exception.BadRequestException;
import com.institute.lms.exception.DuplicateResourceException;
import com.institute.lms.repository.UserRepository;
import com.institute.lms.service.UserService;
import com.institute.lms.service.subscription.QuotaGuard;
import com.institute.lms.subscription.LimitKey;
import com.institute.lms.util.OrganizationContext;
import com.institute.lms.util.UserContext;
import org.springframework.http.ResponseEntity;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/faculty")
public class FacultyController {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final UserService userService;
    private final QuotaGuard quotaGuard;
    private final OrganizationContext organizationContext;
    private final UserContext userContext;

    public FacultyController(UserRepository userRepository,
                             PasswordEncoder passwordEncoder,
                             UserService userService,
                             QuotaGuard quotaGuard,
                             OrganizationContext organizationContext,
                             UserContext userContext) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.userService = userService;
        this.quotaGuard = quotaGuard;
        this.organizationContext = organizationContext;
        this.userContext = userContext;
    }

    @GetMapping
    public List<StudentResponse> getAllFaculty() {
        return userRepository.findByRole(User.UserRole.INSTRUCTOR)
                .stream()
                .map(userService::toResponse)
                .collect(Collectors.toList());
    }

    /**
     * Creates a faculty account, consuming one faculty seat from the plan.
     *
     * <p>A faculty seat is a platform login and is not the same unit as a purchased
     * training hour — the two are priced separately and must not be conflated.
     *
     * <p>Two bugs are fixed here relative to the original. The duplicate check used
     * {@code existsByEmail}, a <em>global</em> lookup, even though email is unique per
     * organization in the schema ({@code uk_users_org_email}, V28) — so creating faculty
     * failed merely because a different academy already had that address. And both
     * failure paths returned a bodiless 400, giving the admin no idea whether the
     * problem was a duplicate, a limit, or something else.
     */
    @PostMapping
    public ResponseEntity<StudentResponse> createFaculty(@RequestBody StudentRequest request) {
        userContext.requireOrgAdmin();
        if (request.getEmail() == null || request.getEmail().isBlank()) {
            throw BadRequestException.field("email", "is required");
        }

        Long orgId = organizationContext.getCurrentOrgId();
        if (orgId != null) {
            quotaGuard.requireCapacity(orgId, LimitKey.MAX_FACULTY_ACCOUNTS, 1);
            if (userRepository.existsEmailInOrg(orgId, request.getEmail())) {
                throw DuplicateResourceException.of("Faculty member", "email", request.getEmail());
            }
        } else if (userRepository.existsByEmail(request.getEmail())) {
            // No tenant context: a platform-level call, where the global check is the
            // only one available.
            throw DuplicateResourceException.of("Faculty member", "email", request.getEmail());
        }

        User user = new User();
        user.setName(request.getName());
        user.setEmail(request.getEmail());
        user.setPassword(passwordEncoder.encode(request.getPassword() != null && !request.getPassword().isEmpty()
                ? request.getPassword() : "faculty123"));
        user.setPhone(request.getPhone());
        user.setRole(User.UserRole.INSTRUCTOR);
        user.setIsActive(request.getIsActive() != null ? request.getIsActive() : true);
        user.setIsEmailVerified(false);

        return ResponseEntity.ok(userService.toResponse(userRepository.save(user)));
    }

    @PutMapping("/{id}")
    public ResponseEntity<StudentResponse> updateFaculty(@PathVariable Long id, @RequestBody StudentRequest request) {
        userContext.requireOrgAdmin();
        return userRepository.findById(id)
                .filter(user -> user.getRole() == User.UserRole.INSTRUCTOR)
                .map(user -> {
                    user.setName(request.getName());
                    user.setEmail(request.getEmail());
                    user.setPhone(request.getPhone());
                    if (request.getPassword() != null && !request.getPassword().isEmpty()) {
                        user.setPassword(passwordEncoder.encode(request.getPassword()));
                    }
                    if (request.getIsActive() != null) {
                        user.setIsActive(request.getIsActive());
                    }
                    return ResponseEntity.ok(userService.toResponse(userRepository.save(user)));
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteFaculty(@PathVariable Long id) {
        userContext.requireOrgAdmin();
        var userOpt = userRepository.findById(id);
        if (userOpt.isEmpty() || userOpt.get().getRole() != User.UserRole.INSTRUCTOR) {
            return ResponseEntity.notFound().build();
        }
        userRepository.delete(userOpt.get());
        return ResponseEntity.ok().build();
    }

}
