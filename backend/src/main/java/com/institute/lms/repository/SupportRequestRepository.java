package com.institute.lms.repository;

import com.institute.lms.entity.SupportRequest;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface SupportRequestRepository extends JpaRepository<SupportRequest, Long> {

    List<SupportRequest> findByStatusOrderByIdDesc(String status);

    List<SupportRequest> findByStudentIdOrderByIdDesc(Long studentId);

    long countByStatus(String status);
}
