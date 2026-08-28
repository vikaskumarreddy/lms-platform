package com.institute.lms.controller;

import com.institute.lms.entity.PlacementDrive;
import com.institute.lms.entity.SupportRequest;
import com.institute.lms.entity.User;
import com.institute.lms.repository.PlacementDriveRepository;
import com.institute.lms.repository.SupportRequestRepository;
import com.institute.lms.repository.UserRepository;
import com.institute.lms.service.NotificationService;
import com.institute.lms.util.OrganizationContext;
import com.institute.lms.util.UserContext;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Student-initiated placement support questions.
 *
 * <p>A student picks a drive (or "Other" + a free-text company name) from the
 * mobile app's "Request Support" screen. Org admins see the queue in the
 * Placements page's Support tab and reply once; the student then sees the
 * reply in-app. There is no approve/reject cycle here — every request is
 * answered, not decided.
 */
@RestController
@RequestMapping("/api/support-requests")
public class SupportRequestController {

    private final SupportRequestRepository requestRepository;
    private final UserRepository userRepository;
    private final PlacementDriveRepository driveRepository;
    private final NotificationService notificationService;
    private final OrganizationContext organizationContext;
    private final UserContext userContext;

    public SupportRequestController(SupportRequestRepository requestRepository,
                                     UserRepository userRepository,
                                     PlacementDriveRepository driveRepository,
                                     NotificationService notificationService,
                                     OrganizationContext organizationContext,
                                     UserContext userContext) {
        this.requestRepository = requestRepository;
        this.userRepository = userRepository;
        this.driveRepository = driveRepository;
        this.notificationService = notificationService;
        this.organizationContext = organizationContext;
        this.userContext = userContext;
    }

    // ------------------------------------------------------------------ admin views

    /** The admin queue. Defaults to PENDING; pass ?status=ALL for the full history. */
    @GetMapping
    public List<Map<String, Object>> list(@RequestParam(required = false, defaultValue = "PENDING") String status) {
        userContext.requireOrgAdmin();
        List<SupportRequest> rows = "ALL".equalsIgnoreCase(status)
                ? requestRepository.findAll()
                : requestRepository.findByStatusOrderByIdDesc(status.toUpperCase());

        List<Map<String, Object>> out = new ArrayList<>();
        for (SupportRequest r : rows) out.add(toMap(r));
        out.sort((a, b) -> Long.compare(
                ((Number) b.get("id")).longValue(), ((Number) a.get("id")).longValue()));
        return out;
    }

    @GetMapping("/pending-count")
    public Map<String, Long> pendingCount() {
        userContext.requireOrgAdmin();
        return Map.of("count", requestRepository.countByStatus("PENDING"));
    }

    // ---------------------------------------------------------------- student views

    @GetMapping("/student/{studentId}")
    public List<Map<String, Object>> forStudent(@PathVariable Long studentId) {
        List<Map<String, Object>> out = new ArrayList<>();
        for (SupportRequest r : requestRepository.findByStudentIdOrderByIdDesc(studentId)) {
            out.add(toMap(r));
        }
        return out;
    }

    /** Raise a request. Body: {studentId, driveId?, companyName?, message} */
    @PostMapping
    @Transactional
    public ResponseEntity<?> create(@RequestBody Map<String, Object> body) {
        Long studentId = num(body.get("studentId"));
        Long driveId = num(body.get("driveId"));
        String companyName = body.get("companyName") != null ? String.valueOf(body.get("companyName")).trim() : null;
        String message = body.get("message") != null ? String.valueOf(body.get("message")).trim() : null;

        if (studentId == null) {
            return ResponseEntity.badRequest().body(Map.of("error", "studentId is required."));
        }
        if (message == null || message.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("error", "message is required."));
        }

        User student = userRepository.findById(studentId).orElse(null);
        if (student == null) {
            return ResponseEntity.badRequest().body(Map.of("error", "Student not found."));
        }

        PlacementDrive drive = null;
        if (driveId != null) {
            drive = driveRepository.findById(driveId).orElse(null);
            if (drive == null) {
                return ResponseEntity.badRequest().body(Map.of("error", "Drive not found."));
            }
        } else if (companyName == null || companyName.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("error", "companyName is required when no drive is selected."));
        }

        SupportRequest request = new SupportRequest();
        request.setStudentId(studentId);
        request.setDriveId(driveId);
        request.setCompanyName(drive != null ? drive.getCompanyName() : companyName);
        request.setMessage(message);
        request.setStatus("PENDING");
        request.setOrganizationId(student.getOrganizationId());
        SupportRequest saved = requestRepository.save(request);

        notifyAdmins(student, saved.getCompanyName());

        return ResponseEntity.ok(toMap(saved));
    }

    // ---------------------------------------------------------------------- response

    @PutMapping("/{id}/respond")
    @Transactional
    public ResponseEntity<?> respond(@PathVariable Long id, @RequestBody Map<String, Object> body) {
        userContext.requireOrgAdmin();
        SupportRequest request = requestRepository.findById(id).orElse(null);
        if (request == null) return ResponseEntity.notFound().build();

        String response = body.get("response") != null ? String.valueOf(body.get("response")).trim() : null;
        if (response == null || response.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("error", "response is required."));
        }

        request.setAdminResponse(response);
        request.setStatus("RESPONDED");
        request.setDecidedAt(LocalDateTime.now());
        requestRepository.save(request);

        notificationService.safeNotifyUser(request.getStudentId(),
                "Support request answered",
                "Your question about " + request.getCompanyName() + " has a response. Tap to view.",
                "placement", "/placements");

        return ResponseEntity.ok(toMap(request));
    }

    // ------------------------------------------------------------------- helpers

    private void notifyAdmins(User student, String companyName) {
        try {
            Long orgId = student.getOrganizationId() != null
                    ? student.getOrganizationId() : organizationContext.getCurrentOrgId();
            if (orgId == null) return;

            List<User> admins = new ArrayList<>();
            admins.addAll(userRepository.findNonGhostAdminsByOrganizationId(orgId, "INSTITUTE_ADMIN"));
            admins.addAll(userRepository.findNonGhostAdminsByOrganizationId(orgId, "ADMIN"));
            if (admins.isEmpty()) return;

            notificationService.safeNotify(admins,
                    "Support request received",
                    student.getName() + " asked about " + companyName + ".",
                    "placement", "/placements", "USER", student.getId());
        } catch (Exception e) {
            System.err.println("Could not notify admins of support request: " + e.getMessage());
        }
    }

    private Map<String, Object> toMap(SupportRequest r) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", r.getId());
        m.put("studentId", r.getStudentId());
        userRepository.findById(r.getStudentId()).ifPresent(u -> {
            m.put("studentName", u.getName());
            m.put("studentEmail", u.getEmail());
            m.put("batchId", u.getBatchId());
        });
        m.putIfAbsent("studentName", "Student #" + r.getStudentId());
        m.put("driveId", r.getDriveId());
        m.put("companyName", r.getCompanyName());
        m.put("message", r.getMessage());
        m.put("status", r.getStatus());
        m.put("adminResponse", r.getAdminResponse());
        m.put("decidedAt", r.getDecidedAt());
        m.put("createdAt", r.getCreatedAt());
        return m;
    }

    private static Long num(Object value) {
        return value instanceof Number n ? n.longValue() : null;
    }
}
