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
    List<Exam> findByCourseId(Long courseId);
    List<Exam> findByIsActiveTrue();
}
