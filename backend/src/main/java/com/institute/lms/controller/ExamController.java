package com.institute.lms.controller;

import com.institute.lms.entity.Exam;
import com.institute.lms.entity.ExamSubmission;
import com.institute.lms.entity.User;
import com.institute.lms.repository.ExamRepository;
import com.institute.lms.repository.ExamSubmissionRepository;
import com.institute.lms.repository.UserRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/exams")
public class ExamController {

    private final ExamRepository examRepository;
    private final UserRepository userRepository;
    private final ExamSubmissionRepository examSubmissionRepository;

    public ExamController(ExamRepository examRepository,
                         UserRepository userRepository,
                         ExamSubmissionRepository examSubmissionRepository) {
        this.examRepository = examRepository;
        this.userRepository = userRepository;
        this.examSubmissionRepository = examSubmissionRepository;
    }

    @GetMapping
    public List<Exam> getAllExams() {
        return examRepository.findAll();
    }

    @GetMapping("/batch/{batchId}")
    public List<Exam> getExamsByBatch(@PathVariable Long batchId) {
        return examRepository.findVisibleToBatch(batchId);
    }

    @GetMapping("/course/{courseId}")
    public List<Exam> getExamsByCourse(@PathVariable Long courseId) {
        return examRepository.findByCourseId(courseId);
    }

    @GetMapping("/user/{userId}")
    public ResponseEntity<Map<String, Object>> getExamsByUser(@PathVariable Long userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));

        // Exams with no batch restriction ("All Batches" in the admin portal) are visible
        // to every student, in addition to exams explicitly targeted at the student's own
        // batch. Previously this returned an empty list whenever the student had no batch
        // assigned, hiding "All Batches" exams entirely.
        List<Exam> exams = user.getBatchId() != null
                ? examRepository.findVisibleToBatch(user.getBatchId())
                : examRepository.findAll().stream()
                        .filter(e -> e.getBatchIds() == null || e.getBatchIds().isEmpty())
                        .collect(Collectors.toList());

        List<ExamSubmission> submissions = examSubmissionRepository.findByUserId(userId);
        Map<Long, ExamSubmission> submissionMap = submissions.stream()
                .collect(Collectors.toMap(ExamSubmission::getExamId, s -> s));

        LocalDateTime now = LocalDateTime.now();

        List<Map<String, Object>> examDetails = exams.stream()
                .map(exam -> {
                    Map<String, Object> detail = new LinkedHashMap<>();
                    detail.put("id", exam.getId());
                    detail.put("title", exam.getTitle());
                    detail.put("description", exam.getDescription());
                    detail.put("examDate", exam.getExamDate());
                    detail.put("durationMinutes", exam.getDurationMinutes());
                    detail.put("totalMarks", exam.getTotalMarks());
                    detail.put("passingMarks", exam.getPassingMarks());
                    detail.put("batchIds", exam.getBatchIds());
                    detail.put("courseId", exam.getCourseId());
                    detail.put("isActive", exam.getIsActive());
                    detail.put("link", exam.getLink());

                    ExamSubmission submission = submissionMap.get(exam.getId());
                    if (submission != null) {
                        detail.put("submissionId", submission.getId());
                        detail.put("submittedAt", submission.getSubmittedAt());
                        detail.put("marksObtained", submission.getMarksObtained());
                        detail.put("isGraded", submission.getIsGraded());
                        detail.put("status", "Completed");
                    } else if (exam.getExamDate() != null && exam.getExamDate().isAfter(now)) {
                        detail.put("status", "Upcoming");
                    } else {
                        detail.put("status", "Missed");
                    }

                    Map<String, String> links = new LinkedHashMap<>();
                    links.put("self", "/api/exams/" + exam.getId());
                    links.put("submission", "/api/exams/" + exam.getId() + "/submit");
                    links.put("result", "/api/exams/" + exam.getId() + "/result");
                    if (exam.getLink() != null && !exam.getLink().isEmpty()) {
                        links.put("details", exam.getLink());
                    }
                    detail.put("_links", links);

                    return detail;
                })
                .collect(Collectors.toList());

        long upcomingCount = examDetails.stream().filter(a -> "Upcoming".equals(a.get("status"))).count();
        long completedCount = examDetails.stream().filter(a -> "Completed".equals(a.get("status"))).count();

        double averageScore = examDetails.stream()
                .filter(a -> a.get("marksObtained") != null)
                .mapToInt(a -> (Integer) a.get("marksObtained"))
                .average()
                .orElse(0.0);

        Map<String, Object> response = new LinkedHashMap<>();
        response.put("exams", examDetails);
        response.put("totalExams", exams.size());
        response.put("upcomingCount", upcomingCount);
        response.put("completedCount", completedCount);
        response.put("averageScore", Math.round(averageScore * 100.0) / 100.0);

        return ResponseEntity.ok(response);
    }

    @GetMapping("/{id}")
    public ResponseEntity<Exam> getExamById(@PathVariable Long id) {
        return examRepository.findById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping
    public Exam createExam(@RequestBody Exam exam) {
        if (exam.getIsActive() == null) exam.setIsActive(true);
        return examRepository.save(exam);
    }

    @PutMapping("/{id}")
    public ResponseEntity<Exam> updateExam(@PathVariable Long id, @RequestBody Exam exam) {
        return examRepository.findById(id)
                .map(existing -> {
                    existing.setTitle(exam.getTitle());
                    existing.setDescription(exam.getDescription());
                    existing.setExamDate(exam.getExamDate());
                    existing.setDurationMinutes(exam.getDurationMinutes());
                    existing.setTotalMarks(exam.getTotalMarks());
                    existing.setPassingMarks(exam.getPassingMarks());
                    existing.setBatchIds(exam.getBatchIds());
                    existing.setCourseId(exam.getCourseId());
                    existing.setIsActive(exam.getIsActive());
                    existing.setLink(exam.getLink());
                    return ResponseEntity.ok(examRepository.save(existing));
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteExam(@PathVariable Long id) {
        examRepository.deleteById(id);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/{id}/submit")
    public ResponseEntity<Map<String, Object>> submitExam(@PathVariable Long id, @RequestBody(required = false) Map<String, Object> body) {
        return examRepository.findById(id)
                .map(exam -> {
                    Long userId = body != null && body.get("userId") != null
                            ? ((Number) body.get("userId")).longValue() : null;
                    User user = userId != null ? userRepository.findById(userId).orElse(null) : null;

                    ExamSubmission submission = new ExamSubmission();
                    submission.setExamId(id);
                    if (user != null) submission.setUser(user);
                    submission.setSubmittedAt(LocalDateTime.now());

                    ExamSubmission saved = examSubmissionRepository.save(submission);

                    Map<String, Object> resp = new LinkedHashMap<>();
                    resp.put("submissionId", saved.getId());
                    resp.put("submittedAt", saved.getSubmittedAt());
                    resp.put("status", "Completed");
                    resp.put("message", "Exam submitted successfully");
                    return ResponseEntity.ok(resp);
                })
                .orElse(ResponseEntity.notFound().build());
    }
}