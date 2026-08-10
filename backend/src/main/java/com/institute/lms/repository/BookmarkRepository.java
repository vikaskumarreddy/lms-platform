package com.institute.lms.repository;

import com.institute.lms.entity.Bookmark;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface BookmarkRepository extends JpaRepository<Bookmark, Long> {
    List<Bookmark> findByUserId(Long userId);
    Optional<Bookmark> findByUserIdAndLessonId(Long userId, Long lessonId);
    boolean existsByUserIdAndLessonId(Long userId, Long lessonId);
    void deleteByUserIdAndLessonId(Long userId, Long lessonId);
}
