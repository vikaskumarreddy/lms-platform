package com.institute.lms.repository;

import com.institute.lms.entity.OrgPaymentGatewayConfig;
import com.institute.lms.entity.PaymentGateway;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface OrgPaymentGatewayConfigRepository extends JpaRepository<OrgPaymentGatewayConfig, Long> {
    Optional<OrgPaymentGatewayConfig> findByOrganizationIdAndGateway(Long organizationId, PaymentGateway gateway);
    List<OrgPaymentGatewayConfig> findByOrganizationId(Long organizationId);
}
