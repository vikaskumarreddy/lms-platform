package com.institute.lms.repository;

import com.institute.lms.entity.SubscriptionPlan;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface SubscriptionPlanRepository extends JpaRepository<SubscriptionPlan, Long> {
    List<SubscriptionPlan> findByIsActiveTrue();

    @Query(value = "SELECT * FROM subscription_plans WHERE id = :id LIMIT 1", nativeQuery = true)
    Optional<SubscriptionPlan> findAnyById(@Param("id") Long id);

    @Query(value = "SELECT * FROM subscription_plans WHERE is_active = true AND (:orgId IS NULL OR organization_id = :orgId)", nativeQuery = true)
    List<SubscriptionPlan> findActiveByOrgIdNative(@Param("orgId") Long orgId);

    @Query(value = "SELECT * FROM subscription_plans WHERE is_active = true", nativeQuery = true)
    List<SubscriptionPlan> findAllActivePlansNative();
}