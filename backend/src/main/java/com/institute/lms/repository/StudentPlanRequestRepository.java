package com.institute.lms.repository;

import com.institute.lms.entity.StudentPlanRequest;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface StudentPlanRequestRepository extends JpaRepository<StudentPlanRequest, Long> {

    List<StudentPlanRequest> findByStatusOrderByIdDesc(String status);

    List<StudentPlanRequest> findByStudentIdOrderByIdDesc(Long studentId);

    /** The student's open ask, if any — used to block duplicates and to show pending state. */
    Optional<StudentPlanRequest> findFirstByStudentIdAndStatus(Long studentId, String status);

    long countByStatus(String status);
}
