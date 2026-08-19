package com.institute.lms.repository;

import com.institute.lms.entity.OrgCoupon;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

/** Promotional codes. Platform-level, not tenant-scoped. */
@Repository
public interface OrgCouponRepository extends JpaRepository<OrgCoupon, Long> {

    Optional<OrgCoupon> findByCodeIgnoreCase(String code);

    List<OrgCoupon> findByIsActiveTrue();

    List<OrgCoupon> findAllByOrderByCreatedAtDesc();
}
