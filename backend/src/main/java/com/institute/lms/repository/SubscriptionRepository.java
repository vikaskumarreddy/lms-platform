package com.institute.lms.repository;

import com.institute.lms.entity.Subscription;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface SubscriptionRepository extends JpaRepository<Subscription, Long> {
    @EntityGraph(attributePaths = {"user", "plan"})
    List<Subscription> findAll();

    @EntityGraph(attributePaths = {"plan"})
    List<Subscription> findByUserIdAndStatus(Long userId, String status);

    @EntityGraph(attributePaths = {"user", "plan"})
    List<Subscription> findByUserId(Long userId);

    long countByStatus(String status);
}