package com.institute.lms.controller;

import com.institute.lms.dto.user.StudentRequest;
import com.institute.lms.dto.user.StudentResponse;
import com.institute.lms.service.UserService;
import com.institute.lms.service.subscription.QuotaGuard;
import com.institute.lms.util.OrganizationContext;
import com.institute.lms.util.UserContext;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/students")
public class UserController {

    private final UserService userService;
    private final UserContext userContext;
    private final QuotaGuard quotaGuard;
    private final OrganizationContext organizationContext;

    public UserController(UserService userService,
                          UserContext userContext,
                          QuotaGuard quotaGuard,
                          OrganizationContext organizationContext) {
        this.userService = userService;
        this.userContext = userContext;
        this.quotaGuard = quotaGuard;
        this.organizationContext = organizationContext;
    }

    @GetMapping
    public List<StudentResponse> getAllStudents() {
        // Faculty only see students in their own batch.
        if (userContext.isFaculty()) {
            Long batchId = userContext.facultyBatchId();
            if (batchId == null) return List.of();
            return userService.getAllStudents().stream()
                    .filter(s -> batchId.equals(s.getBatchId()))
                    .collect(Collectors.toList());
        }
        return userService.getAllStudents();
    }

    @GetMapping("/{id}")
    public ResponseEntity<StudentResponse> getStudentById(@PathVariable Long id) {
        return userService.getStudentById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @GetMapping("/by-email/{email}")
    public ResponseEntity<StudentResponse> getStudentByEmail(@PathVariable String email) {
        return userService.getStudentByEmail(email)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    /**
     * Enrols a new student.
     *
     * <p>Guarded against the plan's student intake ceiling. Note the guard is not a cap
     * on stored records — alumni and dormant accounts are meant to stay for free — it
     * only refuses intake once the tenant has exhausted both their active-student
     * allowance and the overage headroom their plan permits.
     *
     * <p>Exceptions are deliberately not caught here. The previous
     * {@code catch (RuntimeException)} returned a bodiless 400, which would have thrown
     * away the whole typed error envelope — the admin would see "Bad Request" instead of
     * being told which limit they hit and what to upgrade to.
     */
    @PostMapping
    public ResponseEntity<StudentResponse> createStudent(@Valid @RequestBody StudentRequest request) {
        Long orgId = organizationContext.getCurrentOrgId();
        if (orgId != null) {
            quotaGuard.requireStudentIntake(orgId, 1);
        }
        return ResponseEntity.ok(userService.createStudent(request));
    }

    @PutMapping("/{id}")
    public ResponseEntity<StudentResponse> updateStudent(@PathVariable Long id, @Valid @RequestBody StudentRequest request) {
        return userService.updateStudent(id, request)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteStudent(@PathVariable Long id) {
        if (userService.deleteStudent(id)) {
            return ResponseEntity.ok().build();
        }
        return ResponseEntity.notFound().build();
    }

    /**
     * Registers/refreshes the mobile app's FCM device token for push
     * notifications. Called on login and whenever Firebase rotates the token.
     */
    @PutMapping("/{id}/fcm-token")
    public ResponseEntity<Void> updateFcmToken(@PathVariable Long id, @RequestBody java.util.Map<String, String> body) {
        boolean updated = userService.updateFcmToken(id, body.get("fcmToken"));
        return updated ? ResponseEntity.ok().build() : ResponseEntity.notFound().build();
    }
}