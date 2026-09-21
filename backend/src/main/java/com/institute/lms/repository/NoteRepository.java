package com.institute.lms.repository;

import com.institute.lms.entity.Note;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface NoteRepository extends JpaRepository<Note, Long> {
    List<Note> findByUserIdOrderByUpdatedAtDesc(Long userId);
    List<Note> findByUserIdAndLessonId(Long userId, Long lessonId);
    List<Note> findByUserIdAndTopicId(Long userId, Long topicId);
}
