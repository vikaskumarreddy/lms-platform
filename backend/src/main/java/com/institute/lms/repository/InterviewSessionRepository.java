package com.institute.lms.repository;

import com.institute.lms.entity.InterviewSession;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface InterviewSessionRepository extends JpaRepository<InterviewSession, Long> {

    Optional<InterviewSession> findByRoomCode(String roomCode);

    Optional<InterviewSession> findBySlotId(Long slotId);

    List<InterviewSession> findByCandidateIdOrderByCreatedAtDesc(Long candidateId);

    List<InterviewSession> findByInterviewerIdOrderByCreatedAtDesc(Long interviewerId);
}
