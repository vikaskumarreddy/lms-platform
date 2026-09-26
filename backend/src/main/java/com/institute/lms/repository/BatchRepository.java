package com.institute.lms.repository;

import com.institute.lms.entity.Batch;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface BatchRepository extends JpaRepository<Batch, Long> {
    List<Batch> findByIsActiveTrue();
    List<Batch> findByPlanId(Long planId);
    List<Batch> findByMentorId(Long mentorId);

    @Query(value = "SELECT * FROM batches WHERE id = :id LIMIT 1", nativeQuery = true)
    Optional<Batch> findAnyById(@Param("id") Long id);
}