package com.institute.lms.repository;

import com.institute.lms.entity.DailyChallengeAttempt;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Repository
public interface DailyChallengeAttemptRepository extends JpaRepository<DailyChallengeAttempt, Long> {
    List<DailyChallengeAttempt> findByUserId(Long userId);

    @Query("SELECT d FROM DailyChallengeAttempt d WHERE d.userId = :userId AND d.completedAt >= :since ORDER BY d.completedAt DESC")
    List<DailyChallengeAttempt> findByUserIdSince(@Param("userId") Long userId, @Param("since") LocalDateTime since);

    @Query("SELECT d FROM DailyChallengeAttempt d WHERE d.userId = :userId AND d.completedAt >= :startOfDay AND d.completedAt <= :endOfDay")
    List<DailyChallengeAttempt> findAttemptsToday(@Param("userId") Long userId,
                                                 @Param("startOfDay") LocalDateTime startOfDay,
                                                 @Param("endOfDay") LocalDateTime endOfDay);
}
