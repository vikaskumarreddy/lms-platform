package com.institute.lms.repository;

import com.institute.lms.entity.StudentPaymentInfo;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.Optional;

@Repository
public interface StudentPaymentInfoRepository extends JpaRepository<StudentPaymentInfo, Long> {
  Optional<StudentPaymentInfo> findByStudentIdAndOrganizationId(Long studentId, Long organizationId);
}
