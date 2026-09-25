package com.institute.lms.repository;

import com.institute.lms.entity.LessonAiChatMessage;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Repository
public interface LessonAiChatMessageRepository extends JpaRepository<LessonAiChatMessage, Long> {

    List<LessonAiChatMessage> findByUserIdAndLessonIdOrderByCreatedAtAsc(Long userId, Long lessonId);

    long countByUserIdAndLessonIdAndRole(Long userId, Long lessonId, String role);

    @Modifying
    @Transactional
    @Query("DELETE FROM LessonAiChatMessage m WHERE m.userId = :userId AND m.lessonId = :lessonId")
    void deleteByUserIdAndLessonId(@Param("userId") Long userId, @Param("lessonId") Long lessonId);
}
