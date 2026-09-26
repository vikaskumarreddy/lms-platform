package com.institute.lms.repository;

import com.institute.lms.entity.BatchRule;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface BatchRuleRepository extends JpaRepository<BatchRule, Long> {

    List<BatchRule> findByPlanId(Long planId);

    List<BatchRule> findByIsActiveTrue();

    @Query(value = "SELECT * FROM batch_rules WHERE organization_id = :orgId ORDER BY priority ASC, id ASC", nativeQuery = true)
    List<BatchRule> findAllByOrgNative(@Param("orgId") Long orgId);

    @Query(value = "SELECT * FROM batch_rules WHERE organization_id = :orgId AND plan_id = :planId AND is_active = true ORDER BY priority ASC, id ASC", nativeQuery = true)
    List<BatchRule> findActiveByOrgAndPlanNative(@Param("orgId") Long orgId, @Param("planId") Long planId);
}
