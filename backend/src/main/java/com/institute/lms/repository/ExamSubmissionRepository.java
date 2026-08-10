package com.institute.lms.repository;

import com.institute.lms.entity.ExamSubmission;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface ExamSubmissionRepository extends JpaRepository<ExamSubmission, Long> {
    List<ExamSubmission> findByUserId(Long userId);
    List<ExamSubmission> findByExamId(Long examId);
    Optional<ExamSubmission> findByUserIdAndExamId(Long userId, Long examId);
    long countByExamId(Long examId);
    long countByExamIdAndIsGradedTrue(Long examId);
}