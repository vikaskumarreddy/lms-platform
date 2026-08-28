package com.institute.lms.repository;

import com.institute.lms.entity.OrgRazorpayConfig;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.Optional;

@Repository
public interface OrgRazorpayConfigRepository extends JpaRepository<OrgRazorpayConfig, Long> {
  Optional<OrgRazorpayConfig> findByOrganizationId(Long organizationId);
}
