package com.institute.lms.repository;

import com.institute.lms.entity.Assignment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface AssignmentRepository extends JpaRepository<Assignment, Long> {
    @Query(value = "SELECT * FROM assignments WHERE batch_ids IS NOT NULL AND CONCAT(',', batch_ids, ',') LIKE CONCAT('%,', :batchId, ',%')", nativeQuery = true)
    List<Assignment> findByBatchIdsContaining(@Param("batchId") Long batchId);
    List<Assignment> findByCourseId(Long courseId);
    List<Assignment> findByIsActiveTrue();
}
