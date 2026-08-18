package com.institute.lms.controller;

import com.institute.lms.dto.user.StudentResponse;
import com.institute.lms.entity.User;
import com.institute.lms.repository.UserRepository;
import com.institute.lms.service.UserService;
import com.institute.lms.util.OrganizationContext;
import com.institute.lms.util.UserContext;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.Optional;

@RestController
@RequestMapping("/api/org/faculty")
public class FacultyDirectoryController {

    private final UserService userService;
    private final UserRepository userRepository;
    private final UserContext userContext;
    private final OrganizationContext organizationContext;

    public FacultyDirectoryController(UserService userService, UserRepository userRepository,
                                      UserContext userContext, OrganizationContext organizationContext) {
        this.userService = userService;
        this.userRepository = userRepository;
        this.userContext = userContext;
        this.organizationContext = organizationContext;
    }

    @GetMapping
    public ResponseEntity<List<StudentResponse>> getAllFacultyInOrganization() {
        if (!isOrgAdminOrSuperAdmin()) return ResponseEntity.status(403).build();
        return ResponseEntity.ok(userService.getFacultyInCurrentOrganization());
    }

    @PostMapping
    public ResponseEntity<StudentResponse> createFaculty(@RequestBody Map<String, String> request) {
        if (!isOrgAdminOrSuperAdmin()) return ResponseEntity.status(403).build();
        String email = request.get("email");
        String name = request.get("name");
        String password = request.get("password");
        String phone = request.get("phone");
        if (email == null || name == null) return ResponseEntity.badRequest().build();
        try {
            User faculty = userService.createFacultyInCurrentOrganization(email, name, password, phone);
            return ResponseEntity.ok(userService.toResponse(faculty));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().build();
        }
    }

    @GetMapping("/{id}")
    public ResponseEntity<StudentResponse> getFacultyById(@PathVariable Long id) {
        if (!isOrgAdminOrSuperAdmin()) return ResponseEntity.status(403).build();
        Long orgId = organizationContext.getCurrentOrgId();
        if (orgId == null) return ResponseEntity.badRequest().build();
        Optional<User> faculty = userRepository.findByOrganizationIdAndId(orgId, id)
                .filter(u -> u.getRole() == User.UserRole.INSTRUCTOR);
        return faculty.map(u -> ResponseEntity.ok(userService.toResponse(u)))
                .orElseGet(() -> ResponseEntity.notFound().build());
    }

    @PutMapping("/{id}")
    public ResponseEntity<StudentResponse> updateFaculty(@PathVariable Long id,
                                                          @RequestBody Map<String, Object> request) {
        if (!isOrgAdminOrSuperAdmin()) return ResponseEntity.status(403).build();
        Long orgId = organizationContext.getCurrentOrgId();
        if (orgId == null) return ResponseEntity.badRequest().build();
        Optional<User> faculty = userRepository.findByOrganizationIdAndId(orgId, id)
                .filter(u -> u.getRole() == User.UserRole.INSTRUCTOR);
        if (faculty.isEmpty()) return ResponseEntity.notFound().build();
        User user = faculty.get();
        if (request.get("name") != null) user.setName((String) request.get("name"));
        if (request.get("phone") != null) user.setPhone((String) request.get("phone"));
        if (request.get("isActive") != null) user.setIsActive((Boolean) request.get("isActive"));
        return ResponseEntity.ok(userService.toResponse(userRepository.save(user)));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteFaculty(@PathVariable Long id) {
        if (!isOrgAdminOrSuperAdmin()) return ResponseEntity.status(403).build();
        Long orgId = organizationContext.getCurrentOrgId();
        if (orgId == null) return ResponseEntity.badRequest().build();
        Optional<User> faculty = userRepository.findByOrganizationIdAndId(orgId, id);
        if (faculty.isEmpty()) return ResponseEntity.notFound().build();
        userRepository.deleteById(id);
        return ResponseEntity.ok().build();
    }

    private boolean isOrgAdminOrSuperAdmin() {
        User u = userContext.currentUser();
        return u != null && (u.getRole() == User.UserRole.ADMIN || u.getRole() == User.UserRole.INSTITUTE_ADMIN);
    }
}
