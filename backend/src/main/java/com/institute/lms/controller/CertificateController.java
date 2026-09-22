package com.institute.lms.controller;

import com.institute.lms.entity.Certificate;
import com.institute.lms.entity.User;
import com.institute.lms.repository.CertificateRepository;
import com.institute.lms.repository.UserRepository;
import com.institute.lms.util.UserContext;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import com.institute.lms.service.NotificationService;

@RestController
@RequestMapping("/api/certificates")
public class CertificateController {

    private final CertificateRepository certificateRepository;
    private final NotificationService notificationService;
    private final UserRepository userRepository;
    private final UserContext userContext;

    public CertificateController(CertificateRepository certificateRepository, UserRepository userRepository,
                                 UserContext userContext,
                                 NotificationService notificationService) {
        this.certificateRepository = certificateRepository;
        this.userRepository = userRepository;
        this.userContext = userContext;
        this.notificationService = notificationService;
    }

    @GetMapping
    public List<Map<String, Object>> getAll() {
        List<Map<String, Object>> all = certificateRepository.findAll().stream().map(this::toMap).collect(Collectors.toList());
        if (userContext.isFaculty()) {
            Long batchId = userContext.facultyBatchId();
            if (batchId == null) return List.of();
            return all.stream()
                    .filter(m -> {
                        Object uid = m.get("userId");
                        if (!(uid instanceof Number number)) return false;
                        User u = userRepository.findById(number.longValue()).orElse(null);
                        return u != null && batchId.equals(u.getBatchId());
                    })
                    .collect(Collectors.toList());
        }
        return all;
    }

    @GetMapping("/user/{userId}")
    public List<Map<String, Object>> getForUser(@PathVariable Long userId) {
        return certificateRepository.findByUserId(userId).stream().map(this::toMap).collect(Collectors.toList());
    }

    /**
     * Public verification endpoint: returns the official verified certificate data
     * for a given credentialId. Open without authentication so anyone scanning the
     * QR code or viewing LinkedIn certification links can verify legitimacy.
     */
    @GetMapping("/verify/{credentialId}")
    public ResponseEntity<Map<String, Object>> verifyCertificate(@PathVariable String credentialId) {
        return certificateRepository.findByCredentialId(credentialId)
                .map(cert -> {
                    Map<String, Object> map = toMap(cert);
                    map.put("status", "VERIFIED");
                    map.put("verifiedAt", java.time.LocalDateTime.now().toString());
                    return ResponseEntity.ok(map);
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping
    public ResponseEntity<Map<String, Object>> create(@RequestBody Map<String, Object> body) {
        userContext.requireOrgAdminOrFaculty();
        Long userId = body.get("userId") != null ? ((Number) body.get("userId")).longValue() : null;
        User user = userId != null ? userRepository.findById(userId).orElse(null) : null;
        if (user == null) return ResponseEntity.badRequest().build();

        Certificate cert = new Certificate();
        cert.setUserId(userId);
        cert.setInstituteName(String.valueOf(body.getOrDefault("instituteName", "")));
        cert.setCourseName(String.valueOf(body.getOrDefault("courseName", "")));
        cert.setDuration(body.get("duration") != null ? String.valueOf(body.get("duration")) : null);
        cert.setCredentialId("CERT-" + userId + "-" + System.currentTimeMillis());

        Certificate saved = certificateRepository.save(cert);

        // A certificate belongs to exactly one student, so no audience resolution.
        notificationService.safeNotifyUser(
                userId,
                "Certificate issued",
                "Your certificate for " + saved.getCourseName() + " is ready to download.",
                "certificate", "/certificates");

        return ResponseEntity.ok(toMap(saved));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        userContext.requireOrgAdminOrFaculty();
        if (!certificateRepository.existsById(id)) return ResponseEntity.notFound().build();
        certificateRepository.deleteById(id);
        return ResponseEntity.ok().build();
    }

    private Map<String, Object> toMap(Certificate cert) {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("id", cert.getId());
        map.put("userId", cert.getUserId());
        User user = userRepository.findById(cert.getUserId()).orElse(null);
        map.put("studentName", user != null ? user.getName() : null);
        map.put("studentEmail", user != null ? user.getEmail() : null);
        map.put("instituteName", cert.getInstituteName());
        map.put("courseName", cert.getCourseName());
        map.put("duration", cert.getDuration());
        map.put("credentialId", cert.getCredentialId());
        map.put("issueDate", cert.getIssueDate() != null ? cert.getIssueDate().toString() : null);
        return map;
    }
}
