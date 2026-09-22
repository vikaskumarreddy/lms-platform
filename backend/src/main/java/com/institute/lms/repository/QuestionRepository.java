package com.institute.lms.repository;

import com.institute.lms.entity.Question;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface QuestionRepository extends JpaRepository<Question, Long> {
    List<Question> findByBatchId(Long batchId);
    List<Question> findByPlanId(Long planId);
    List<Question> findByUserId(Long userId);
    List<Question> findByCategoryIgnoreCase(String category);

    @Query("SELECT q FROM Question q WHERE q.batchId IS NULL AND q.planId IS NULL")
    List<Question> findGeneralQuestions();

    long countByIsAnsweredFalse();
    long countByUserIdAndCreatedAtAfter(Long userId, java.time.LocalDateTime timestamp);

    // Questions with batchId == null ("All Batches" in the admin portal) must be visible
    // to every student, regardless of plan, in addition to batch-specific questions.
    @Query("SELECT q FROM Question q WHERE q.batchId IS NULL OR q.batchId = :batchId")
    List<Question> findVisibleToBatch(@Param("batchId") Long batchId);
}