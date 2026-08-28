package com.institute.lms.repository;

import com.institute.lms.entity.Comment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface CommentRepository extends JpaRepository<Comment, Long> {
    List<Comment> findByLessonIdOrderByCreatedAtDesc(Long lessonId);
}
