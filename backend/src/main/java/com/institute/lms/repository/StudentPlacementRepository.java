package com.institute.lms.repository;

import com.institute.lms.entity.StudentPlacement;
import com.institute.lms.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface StudentPlacementRepository extends JpaRepository<StudentPlacement, Long> {
    List<StudentPlacement> findByUser(User user);
    List<StudentPlacement> findByUserId(Long userId);
    List<StudentPlacement> findByIsPlacedTrue();
    long countByIsPlacedTrue();
    Optional<StudentPlacement> findByUserIdAndIsPlacedTrue(Long userId);
}