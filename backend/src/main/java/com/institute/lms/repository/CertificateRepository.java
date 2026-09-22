package com.institute.lms.repository;

import com.institute.lms.entity.Certificate;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface CertificateRepository extends JpaRepository<Certificate, Long> {
    List<Certificate> findByUserId(Long userId);
    List<Certificate> findTop5ByOrderByIssueDateDesc();
    java.util.Optional<Certificate> findByCredentialId(String credentialId);
}
