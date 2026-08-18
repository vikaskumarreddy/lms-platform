package com.institute.lms.repository;

import com.institute.lms.entity.OrgSubscription;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface OrgSubscriptionRepository extends JpaRepository<OrgSubscription, Long> {
    List<OrgSubscription> findByIsActiveTrue();
}