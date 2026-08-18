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

@RestController
@RequestMapping("/api/certificates")
public class CertificateController {

    private final CertificateRepository certificateRepository;
    private final UserRepository userRepository;
    private final UserContext userContext;

    public CertificateController(CertificateRepository certificateRepository, UserRepository userRepository,
                                 UserContext userContext) {
        this.certificateRepository = certificateRepository;
        this.userRepository = userRepository;
        this.userContext = userContext;
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

    @PostMapping
    public ResponseEntity<Map<String, Object>> create(@RequestBody Map<String, Object> body) {
        Long userId = body.get("userId") != null ? ((Number) body.get("userId")).longValue() : null;
        User user = userId != null ? userRepository.findById(userId).orElse(null) : null;
        if (user == null) return ResponseEntity.badRequest().build();

        Certificate cert = new Certificate();
        cert.setUserId(userId);
        cert.setInstituteName(String.valueOf(body.getOrDefault("instituteName", "")));
        cert.setCourseName(String.valueOf(body.getOrDefault("courseName", "")));
        cert.setDuration(body.get("duration") != null ? String.valueOf(body.get("duration")) : null);
        cert.setCredentialId("CERT-" + userId + "-" + System.currentTimeMillis());

        return ResponseEntity.ok(toMap(certificateRepository.save(cert)));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
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
