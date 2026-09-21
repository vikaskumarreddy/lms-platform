package com.institute.lms.repository;

import com.institute.lms.entity.StudyTopic;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface StudyTopicRepository extends JpaRepository<StudyTopic, Long> {
    List<StudyTopic> findByUserIdOrderByUpdatedAtDescIdDesc(Long userId);
}
