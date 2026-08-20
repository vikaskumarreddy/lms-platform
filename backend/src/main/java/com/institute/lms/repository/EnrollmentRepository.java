package com.institute.lms.repository;

import com.institute.lms.entity.Enrollment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface EnrollmentRepository extends JpaRepository<Enrollment, Long> {
    List<Enrollment> findTop5ByOrderByEnrolledAtDesc();
    List<Enrollment> findByUserId(Long userId);
}
