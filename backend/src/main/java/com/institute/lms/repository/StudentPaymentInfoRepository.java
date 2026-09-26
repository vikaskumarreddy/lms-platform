package com.institute.lms.repository;

import com.institute.lms.entity.StudentPaymentInfo;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.Optional;

@Repository
public interface StudentPaymentInfoRepository extends JpaRepository<StudentPaymentInfo, Long> {
  Optional<StudentPaymentInfo> findByStudentIdAndOrganizationId(Long studentId, Long organizationId);
  java.util.List<StudentPaymentInfo> findByOrganizationId(Long organizationId);

  /** Cross-tenant lookup by studentId and organizationId used by webhooks without thread tenant context. */
  @org.springframework.data.jpa.repository.Query(value = "SELECT * FROM student_payment_info WHERE student_id = :studentId AND organization_id = :orgId LIMIT 1", nativeQuery = true)
  Optional<StudentPaymentInfo> findAnyByStudentIdAndOrganizationId(
      @org.springframework.data.repository.query.Param("studentId") Long studentId,
      @org.springframework.data.repository.query.Param("orgId") Long organizationId);
}
