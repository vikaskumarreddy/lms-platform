package com.institute.lms.repository;

import com.institute.lms.entity.Assignment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface AssignmentRepository extends JpaRepository<Assignment, Long> {
    // NOTE: native SQL queries bypass Hibernate's tenantFilter (@Filter) entirely,
    // so organization_id is filtered explicitly here. Callers MUST pass the current
    // tenant's id (e.g. via OrganizationContext#getCurrentOrgId()); passing null
    // matches legacy/un-migrated rows only (organization_id IS NULL), never "all tenants".
    @Query(value = "SELECT * FROM assignments WHERE batch_ids IS NOT NULL AND CONCAT(',', batch_ids, ',') LIKE CONCAT('%,', :batchId, ',%') AND (organization_id = :orgId OR (:orgId IS NULL AND organization_id IS NULL))", nativeQuery = true)
    List<Assignment> findByBatchIdsContaining(@Param("batchId") Long batchId, @Param("orgId") Long orgId);

    // "All Batches" assignments (batch_ids left empty in the admin portal) must be visible
    // to every student regardless of their batch, in addition to assignments explicitly
    // targeted at the student's batch.
    @Query(value = "SELECT * FROM assignments WHERE (batch_ids IS NULL OR batch_ids = '' OR CONCAT(',', batch_ids, ',') LIKE CONCAT('%,', :batchId, ',%')) AND (organization_id = :orgId OR (:orgId IS NULL AND organization_id IS NULL))", nativeQuery = true)
    List<Assignment> findVisibleToBatch(@Param("batchId") Long batchId, @Param("orgId") Long orgId);
    List<Assignment> findByCourseId(Long courseId);
    List<Assignment> findByIsActiveTrue();
}
