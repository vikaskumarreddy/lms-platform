package com.institute.lms.controller;

import com.institute.lms.entity.StudentPlanRequest;
import com.institute.lms.entity.SubscriptionPlan;
import com.institute.lms.entity.User;
import com.institute.lms.repository.StudentPlanRequestRepository;
import com.institute.lms.repository.SubscriptionPlanRepository;
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
 * Student-initiated plan upgrades.
 *
 * <p>A student taps "Upgrade Now" in the app, which lands here as a PENDING row.
 * Org admins see the queue on the Subscriptions page and approve or reject it.
 * Only approval moves the student onto the plan — the app can ask, never grant.
 */
@RestController
@RequestMapping("/api/student-plan-requests")
public class StudentPlanRequestController {

    private final StudentPlanRequestRepository requestRepository;
    private final UserRepository userRepository;
    private final SubscriptionPlanRepository planRepository;
    private final NotificationService notificationService;
    private final OrganizationContext organizationContext;
    private final UserContext userContext;

    public StudentPlanRequestController(StudentPlanRequestRepository requestRepository,
                                        UserRepository userRepository,
                                        SubscriptionPlanRepository planRepository,
                                        NotificationService notificationService,
                                        OrganizationContext organizationContext,
                                        UserContext userContext) {
        this.requestRepository = requestRepository;
        this.userRepository = userRepository;
        this.planRepository = planRepository;
        this.notificationService = notificationService;
        this.organizationContext = organizationContext;
        this.userContext = userContext;
    }

    // ------------------------------------------------------------------ admin views

    /** The admin queue. Defaults to PENDING; pass ?status=ALL for the full history. */
    @GetMapping
    public List<Map<String, Object>> list(@RequestParam(required = false, defaultValue = "PENDING") String status) {
        userContext.requireOrgAdmin();
        List<StudentPlanRequest> rows = "ALL".equalsIgnoreCase(status)
                ? requestRepository.findAll()
                : requestRepository.findByStatusOrderByIdDesc(status.toUpperCase());

        List<Map<String, Object>> out = new ArrayList<>();
        for (StudentPlanRequest r : rows) out.add(toMap(r));
        // findAll() has no ordering guarantee, so sort newest-first here rather than
        // letting the admin queue shuffle between refreshes.
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

    /** What this student has already asked for, so the app can show pending state. */
    @GetMapping("/student/{studentId}")
    public List<Map<String, Object>> forStudent(@PathVariable Long studentId) {
        List<Map<String, Object>> out = new ArrayList<>();
        for (StudentPlanRequest r : requestRepository.findByStudentIdOrderByIdDesc(studentId)) {
            out.add(toMap(r));
        }
        return out;
    }

    /** Raise a request. Body: {studentId, requestedPlanId, note?} */
    @PostMapping
    @Transactional
    public ResponseEntity<?> create(@RequestBody Map<String, Object> body) {
        Long studentId = num(body.get("studentId"));
        Long requestedPlanId = num(body.get("requestedPlanId"));
        String note = body.get("note") != null ? String.valueOf(body.get("note")) : null;

        if (studentId == null || requestedPlanId == null) {
            return ResponseEntity.badRequest().body(Map.of("error", "studentId and requestedPlanId are required."));
        }

        User student = userRepository.findById(studentId).orElse(null);
        if (student == null) {
            return ResponseEntity.badRequest().body(Map.of("error", "Student not found."));
        }
        if (planRepository.findById(requestedPlanId).isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of("error", "Plan not found."));
        }
        if (requestedPlanId.equals(student.getPlanId())) {
            return ResponseEntity.badRequest().body(Map.of("error", "You are already on this plan."));
        }

        // One open ask at a time. The DB has a partial unique index too, but failing
        // here gives the app a readable message instead of a constraint violation.
        var existing = requestRepository.findFirstByStudentIdAndStatus(studentId, "PENDING");
        if (existing.isPresent()) {
            return ResponseEntity.badRequest().body(Map.of(
                    "error", "You already have an upgrade request awaiting review."));
        }

        StudentPlanRequest request = new StudentPlanRequest();
        request.setStudentId(studentId);
        request.setRequestedPlanId(requestedPlanId);
        request.setCurrentPlanId(student.getPlanId());
        request.setStudentNote(note);
        request.setStatus("PENDING");
        request.setOrganizationId(student.getOrganizationId());
        StudentPlanRequest saved = requestRepository.save(request);

        notifyAdmins(student, requestedPlanId);

        return ResponseEntity.ok(toMap(saved));
    }

    // -------------------------------------------------------------------- decisions

    @PutMapping("/{id}/approve")
    @Transactional
    public ResponseEntity<?> approve(@PathVariable Long id, @RequestBody(required = false) Map<String, Object> body) {
        userContext.requireOrgAdmin();
        StudentPlanRequest request = requestRepository.findById(id).orElse(null);
        if (request == null) return ResponseEntity.notFound().build();
        if (!request.isPending()) {
            return ResponseEntity.badRequest().body(Map.of("error", "This request has already been decided."));
        }

        User student = userRepository.findById(request.getStudentId()).orElse(null);
        if (student == null) {
            return ResponseEntity.badRequest().body(Map.of("error", "Student no longer exists."));
        }

        // The approval itself is what moves the plan.
        student.setPlanId(request.getRequestedPlanId());
        userRepository.save(student);

        request.setStatus("APPROVED");
        request.setDecisionNote(body != null && body.get("note") != null ? String.valueOf(body.get("note")) : null);
        request.setDecidedAt(LocalDateTime.now());
        requestRepository.save(request);

        String planName = planName(request.getRequestedPlanId());
        notificationService.safeNotifyUser(student.getId(),
                "Upgrade approved",
                "You are now on the " + planName + " plan. Enjoy the new features.",
                "subscription", "/subscription");

        return ResponseEntity.ok(toMap(request));
    }

    @PutMapping("/{id}/reject")
    @Transactional
    public ResponseEntity<?> reject(@PathVariable Long id, @RequestBody(required = false) Map<String, Object> body) {
        userContext.requireOrgAdmin();
        StudentPlanRequest request = requestRepository.findById(id).orElse(null);
        if (request == null) return ResponseEntity.notFound().build();
        if (!request.isPending()) {
            return ResponseEntity.badRequest().body(Map.of("error", "This request has already been decided."));
        }

        String note = body != null && body.get("note") != null ? String.valueOf(body.get("note")) : null;
        request.setStatus("REJECTED");
        request.setDecisionNote(note);
        request.setDecidedAt(LocalDateTime.now());
        requestRepository.save(request);

        notificationService.safeNotifyUser(request.getStudentId(),
                "Upgrade request declined",
                note != null && !note.isBlank()
                        ? note
                        : "Your plan upgrade request was not approved. Talk to your institute for details.",
                "subscription", "/subscription");

        return ResponseEntity.ok(toMap(request));
    }

    // ------------------------------------------------------------------- helpers

    /**
     * Pings the org's admins so a request does not sit unseen until someone happens
     * to open the Subscriptions page.
     */
    private void notifyAdmins(User student, Long requestedPlanId) {
        try {
            Long orgId = student.getOrganizationId() != null
                    ? student.getOrganizationId() : organizationContext.getCurrentOrgId();
            if (orgId == null) return;

            List<User> admins = new ArrayList<>();
            admins.addAll(userRepository.findNonGhostAdminsByOrganizationId(orgId, "INSTITUTE_ADMIN"));
            admins.addAll(userRepository.findNonGhostAdminsByOrganizationId(orgId, "ADMIN"));
            if (admins.isEmpty()) return;

            notificationService.safeNotify(admins,
                    "Plan upgrade requested",
                    student.getName() + " asked to move to " + planName(requestedPlanId) + ".",
                    "subscription", "/subscriptions-admin", "USER", student.getId());
        } catch (Exception e) {
            // Never block the student's request on an admin-side notification problem.
            System.err.println("Could not notify admins of plan request: " + e.getMessage());
        }
    }

    private String planName(Long planId) {
        if (planId == null) return "another";
        return planRepository.findById(planId).map(SubscriptionPlan::getName).orElse("another");
    }

    private Map<String, Object> toMap(StudentPlanRequest r) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", r.getId());
        m.put("studentId", r.getStudentId());
        userRepository.findById(r.getStudentId()).ifPresent(u -> {
            m.put("studentName", u.getName());
            m.put("studentEmail", u.getEmail());
            m.put("batchId", u.getBatchId());
        });
        m.putIfAbsent("studentName", "Student #" + r.getStudentId());
        m.put("requestedPlanId", r.getRequestedPlanId());
        m.put("requestedPlanName", planName(r.getRequestedPlanId()));
        m.put("currentPlanId", r.getCurrentPlanId());
        m.put("currentPlanName", r.getCurrentPlanId() != null ? planName(r.getCurrentPlanId()) : null);
        m.put("status", r.getStatus());
        m.put("studentNote", r.getStudentNote());
        m.put("decisionNote", r.getDecisionNote());
        m.put("decidedAt", r.getDecidedAt());
        m.put("createdAt", r.getCreatedAt());
        return m;
    }

    private static Long num(Object value) {
        return value instanceof Number n ? n.longValue() : null;
    }
}
