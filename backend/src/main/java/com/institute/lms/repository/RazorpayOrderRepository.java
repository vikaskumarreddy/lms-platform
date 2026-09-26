package com.institute.lms.repository;

import com.institute.lms.entity.RazorpayOrder;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.Optional;

@Repository
public interface RazorpayOrderRepository extends JpaRepository<RazorpayOrder, Long> {
  Optional<RazorpayOrder> findByRazorpayOrderId(String razorpayOrderId);
  Optional<RazorpayOrder> findByRazorpayPaymentId(String razorpayPaymentId);

  /** Cross-tenant lookup by orderId used by webhooks and gateway callbacks without tenant context. */
  @org.springframework.data.jpa.repository.Query(value = "SELECT * FROM razorpay_orders WHERE razorpay_order_id = :orderId LIMIT 1", nativeQuery = true)
  Optional<RazorpayOrder> findAnyByRazorpayOrderId(@org.springframework.data.repository.query.Param("orderId") String orderId);

  /** Newest first, so the caller can take the most recent attempt for a student. */
  java.util.List<RazorpayOrder> findByStudentIdOrderByIdDesc(Long studentId);
}
