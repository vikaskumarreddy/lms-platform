package com.institute.lms.repository;

import com.institute.lms.entity.OrgTrainingAgreement;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

/** Training agreements. Platform-level, not tenant-scoped. */
@Repository
public interface OrgTrainingAgreementRepository extends JpaRepository<OrgTrainingAgreement, Long> {

    List<OrgTrainingAgreement> findByOrganizationIdOrderByCreatedAtDesc(Long organizationId);

    List<OrgTrainingAgreement> findByOrganizationIdAndStatus(Long organizationId, String status);

    List<OrgTrainingAgreement> findByStatus(String status);
}
