package com.institute.lms.repository;

import com.institute.lms.entity.Exam;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ExamRepository extends JpaRepository<Exam, Long> {
    // NOTE: native SQL queries bypass Hibernate's tenantFilter (@Filter) entirely,
    // so organization_id is filtered explicitly here. Callers MUST pass the current
    // tenant's id (e.g. via OrganizationContext#getCurrentOrgId()); passing null
    // matches legacy/un-migrated rows only (organization_id IS NULL), never "all tenants".
    @Query(value = "SELECT * FROM exams WHERE batch_ids IS NOT NULL AND CONCAT(',', batch_ids, ',') LIKE CONCAT('%,', :batchId, ',%') AND (organization_id = :orgId OR (:orgId IS NULL AND organization_id IS NULL))", nativeQuery = true)
    List<Exam> findByBatchIdsContaining(@Param("batchId") Long batchId, @Param("orgId") Long orgId);

    // "All Batches" exams (batch_ids left empty in the admin portal) must be visible to
    // every student regardless of their batch, in addition to exams explicitly targeted
    // at the student's batch.
    @Query(value = "SELECT * FROM exams WHERE (batch_ids IS NULL OR batch_ids = '' OR CONCAT(',', batch_ids, ',') LIKE CONCAT('%,', :batchId, ',%')) AND (organization_id = :orgId OR (:orgId IS NULL AND organization_id IS NULL))", nativeQuery = true)
    List<Exam> findVisibleToBatch(@Param("batchId") Long batchId, @Param("orgId") Long orgId);
    List<Exam> findByCourseId(Long courseId);
    List<Exam> findByIsActiveTrue();
}
