package com.institute.lms.repository;

import com.institute.lms.entity.AssignmentSubmission;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface AssignmentSubmissionRepository extends JpaRepository<AssignmentSubmission, Long> {
    List<AssignmentSubmission> findByUserId(Long userId);
    List<AssignmentSubmission> findByAssignmentId(Long assignmentId);
    Optional<AssignmentSubmission> findByUserIdAndAssignmentId(Long userId, Long assignmentId);
    long countByAssignmentId(Long assignmentId);
    long countByAssignmentIdAndIsGradedTrue(Long assignmentId);
}