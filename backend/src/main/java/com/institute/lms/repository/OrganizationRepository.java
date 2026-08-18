package com.institute.lms.repository;

import com.institute.lms.entity.Organization;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface OrganizationRepository extends JpaRepository<Organization, Long> {
    Optional<Organization> findBySlug(String slug);
    Optional<Organization> findByDomain(String domain);
    List<Organization> findByIsActiveTrue();
}
