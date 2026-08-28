package com.institute.lms.repository;

import com.institute.lms.entity.OrgFeatureSettings;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface OrgFeatureSettingsRepository extends JpaRepository<OrgFeatureSettings, Long> {
    Optional<OrgFeatureSettings> findByOrganizationId(Long organizationId);
}
