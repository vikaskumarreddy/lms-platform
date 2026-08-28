package com.institute.lms.repository;

import com.institute.lms.entity.RazorpayOrder;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.Optional;

@Repository
public interface RazorpayOrderRepository extends JpaRepository<RazorpayOrder, Long> {
  Optional<RazorpayOrder> findByRazorpayOrderId(String razorpayOrderId);
  Optional<RazorpayOrder> findByRazorpayPaymentId(String razorpayPaymentId);

  /** Newest first, so the caller can take the most recent attempt for a student. */
  java.util.List<RazorpayOrder> findByStudentIdOrderByIdDesc(Long studentId);
}
