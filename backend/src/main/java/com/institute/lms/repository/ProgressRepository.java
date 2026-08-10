package com.institute.lms.repository;

import com.institute.lms.entity.Progress;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.Set;

@Repository
public interface ProgressRepository extends JpaRepository<Progress, Long> {
    @Query("SELECT p.lesson.id FROM Progress p WHERE p.user.id = :userId AND p.isCompleted = true")
    Set<Long> findCompletedLessonIdsByUserId(@Param("userId") Long userId);

    void deleteByLessonId(Long lessonId);

    Optional<Progress> findByUserIdAndLessonId(Long userId, Long lessonId);

    boolean existsByUserIdAndLessonId(Long userId, Long lessonId);
}
