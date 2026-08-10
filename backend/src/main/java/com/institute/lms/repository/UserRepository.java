package com.institute.lms.repository;

import com.institute.lms.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface UserRepository extends JpaRepository<User, Long> {
    Optional<User> findByEmail(String email);
    boolean existsByEmail(String email);
    boolean existsByPhone(String phone);
    boolean existsByUsername(String username);
    List<User> findByRole(User.UserRole role);
    List<User> findByRoleAndBatchId(User.UserRole role, Long batchId);
    List<User> findByRoleAndPlanId(User.UserRole role, Long planId);
    long countByRole(User.UserRole role);
}
