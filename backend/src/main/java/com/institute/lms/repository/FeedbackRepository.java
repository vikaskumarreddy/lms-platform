package com.institute.lms.repository;

import com.institute.lms.entity.Feedback;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface FeedbackRepository extends JpaRepository<Feedback, Long> {
    List<Feedback> findByUserId(Long userId);
    List<Feedback> findByUserIdOrderByCreatedAtDesc(Long userId);
    List<Feedback> findByCourseId(Long courseId);
    List<Feedback> findByUserIdAndCourseId(Long userId, Long courseId);
    List<Feedback> findAllByOrderByCreatedAtDesc();
}