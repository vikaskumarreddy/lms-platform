package com.institute.lms.repository;

import com.institute.lms.entity.OrgAiConfig;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.Optional;

@Repository
public interface OrgAiConfigRepository extends JpaRepository<OrgAiConfig, Long> {
    Optional<OrgAiConfig> findByOrganizationId(Long organizationId);
}
