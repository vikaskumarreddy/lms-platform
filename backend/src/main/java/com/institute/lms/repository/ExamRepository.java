package com.institute.lms.repository;

import com.institute.lms.entity.Exam;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ExamRepository extends JpaRepository<Exam, Long> {
    @Query(value = "SELECT * FROM exams WHERE batch_ids IS NOT NULL AND CONCAT(',', batch_ids, ',') LIKE CONCAT('%,', :batchId, ',%')", nativeQuery = true)
    List<Exam> findByBatchIdsContaining(@Param("batchId") Long batchId);

    // "All Batches" exams (batch_ids left empty in the admin portal) must be visible to
    // every student regardless of their batch, in addition to exams explicitly targeted
    // at the student's batch.
    @Query(value = "SELECT * FROM exams WHERE batch_ids IS NULL OR batch_ids = '' OR CONCAT(',', batch_ids, ',') LIKE CONCAT('%,', :batchId, ',%')", nativeQuery = true)
    List<Exam> findVisibleToBatch(@Param("batchId") Long batchId);
    List<Exam> findByCourseId(Long courseId);
    List<Exam> findByIsActiveTrue();
}
