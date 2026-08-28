package com.institute.lms.repository;

import com.institute.lms.entity.MessagingChannel;
import com.institute.lms.entity.OrgMessagingConfig;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface OrgMessagingConfigRepository extends JpaRepository<OrgMessagingConfig, Long> {
    Optional<OrgMessagingConfig> findByOrganizationIdAndChannel(Long organizationId, MessagingChannel channel);
    List<OrgMessagingConfig> findByOrganizationId(Long organizationId);
}
