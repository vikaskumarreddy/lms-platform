package com.institute.lms.repository;

import com.institute.lms.entity.OrgCouponRedemption;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

/** Coupon usage records, which enforce per-organization redemption limits. */
@Repository
public interface OrgCouponRedemptionRepository extends JpaRepository<OrgCouponRedemption, Long> {

    long countByCouponIdAndOrganizationId(Long couponId, Long organizationId);

    List<OrgCouponRedemption> findByOrganizationIdOrderByRedeemedAtDesc(Long organizationId);

    List<OrgCouponRedemption> findByCouponId(Long couponId);
}
