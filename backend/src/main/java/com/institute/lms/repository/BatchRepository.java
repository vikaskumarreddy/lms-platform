package com.institute.lms.repository;

import com.institute.lms.entity.Batch;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface BatchRepository extends JpaRepository<Batch, Long> {
    List<Batch> findByIsActiveTrue();
    List<Batch> findByPlanId(Long planId);
    List<Batch> findByMentorId(Long mentorId);
}