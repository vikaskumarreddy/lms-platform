package com.institute.lms.repository;

import com.institute.lms.entity.OrgRazorpayConfig;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.Optional;

@Repository
public interface OrgRazorpayConfigRepository extends JpaRepository<OrgRazorpayConfig, Long> {
  Optional<OrgRazorpayConfig> findByOrganizationId(Long organizationId);

  /** Cross-tenant lookup by organizationId used by webhooks without thread tenant context. */
  @org.springframework.data.jpa.repository.Query(value = "SELECT * FROM org_razorpay_config WHERE organization_id = :orgId LIMIT 1", nativeQuery = true)
  Optional<OrgRazorpayConfig> findAnyByOrganizationId(@org.springframework.data.repository.query.Param("orgId") Long organizationId);
}
