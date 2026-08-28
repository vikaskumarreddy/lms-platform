package com.institute.lms.repository;

import com.institute.lms.entity.PaymentRefund;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.Optional;

@Repository
public interface PaymentRefundRepository extends JpaRepository<PaymentRefund, Long> {
  Optional<PaymentRefund> findByRazorpayRefundId(String refundId);
}
