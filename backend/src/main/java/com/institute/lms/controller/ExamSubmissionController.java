package com.institute.lms.controller;

import com.institute.lms.entity.ExamSubmission;
import com.institute.lms.entity.User;
import com.institute.lms.repository.ExamSubmissionRepository;
import com.institute.lms.repository.UserRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/exam-submissions")
public class ExamSubmissionController {

    private final ExamSubmissionRepository submissionRepository;
    private final UserRepository userRepository;

    public ExamSubmissionController(ExamSubmissionRepository submissionRepository, UserRepository userRepository) {
        this.submissionRepository = submissionRepository;
        this.userRepository = userRepository;
    }

    @GetMapping
    public List<ExamSubmission> getAllSubmissions() {
        return submissionRepository.findAll();
    }

    @GetMapping("/student/{studentId}")
    public List<ExamSubmission> getSubmissionsByStudent(@PathVariable Long studentId) {
        return submissionRepository.findByUserId(studentId);
    }

    @GetMapping("/exam/{examId}")
    public List<ExamSubmission> getSubmissionsByExam(@PathVariable Long examId) {
        return submissionRepository.findByExamId(examId);
    }

    @PostMapping
    public ResponseEntity<ExamSubmission> createSubmission(@RequestBody ExamSubmission submission) {
        User user = userRepository.findById(submission.getUser().getId())
                .orElseThrow(() -> new RuntimeException("User not found"));
        submission.setUser(user);
        submission.setSubmittedAt(java.time.LocalDateTime.now());
        return ResponseEntity.ok(submissionRepository.save(submission));
    }

    @PutMapping("/{id}")
    public ResponseEntity<ExamSubmission> updateSubmission(@PathVariable Long id, @RequestBody ExamSubmission submission) {
        return submissionRepository.findById(id)
                .map(existing -> {
                    existing.setAnswers(submission.getAnswers());
                    existing.setMarksObtained(submission.getMarksObtained());
                    existing.setRemarks(submission.getRemarks());
                    existing.setIsGraded(submission.getIsGraded());
                    return ResponseEntity.ok(submissionRepository.save(existing));
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteSubmission(@PathVariable Long id) {
        submissionRepository.deleteById(id);
        return ResponseEntity.ok().build();
    }
}