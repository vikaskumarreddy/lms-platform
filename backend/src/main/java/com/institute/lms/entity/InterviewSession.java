package com.institute.lms.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * Represents a live 1-on-1 interview session with 100ms video calling,
 * live collaborative coding, problem prompt, and interviewer evaluation rubric.
 */
@Entity
@Table(name = "interview_sessions", indexes = {
        @Index(name = "idx_interview_room_code", columnList = "room_code", unique = true),
        @Index(name = "idx_interview_candidate", columnList = "candidate_id"),
        @Index(name = "idx_interview_slot", columnList = "slot_id")
})
@Data
@NoArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class InterviewSession extends BaseEntity {

    @Column(name = "room_code", nullable = false, unique = true, length = 64)
    private String roomCode;

    @Column(name = "title", nullable = false)
    private String title = "Technical Interview";

    @Column(name = "slot_id")
    private Long slotId;

    @Column(name = "drive_id")
    private Long driveId;

    @Column(name = "candidate_id")
    private Long candidateId;

    @Column(name = "candidate_name")
    private String candidateName;

    @Column(name = "candidate_email")
    private String candidateEmail;

    @Column(name = "interviewer_id")
    private Long interviewerId;

    @Column(name = "interviewer_name")
    private String interviewerName;

    @Column(name = "interviewer_email")
    private String interviewerEmail;

    /** SCHEDULED, WAITING, LIVE, COMPLETED, CANCELLED */
    @Column(nullable = false, length = 32)
    private String status = "SCHEDULED";

    @Column(name = "scheduled_at")
    private LocalDateTime scheduledAt;

    @Column(name = "started_at")
    private LocalDateTime startedAt;

    @Column(name = "ended_at")
    private LocalDateTime endedAt;

    // 100ms Realtime Room metadata
    @Column(name = "hms_room_id")
    private String hmsRoomId;

    @Column(name = "hms_room_code")
    private String hmsRoomCode;

    @Column(name = "hms_meeting_url", length = 1024)
    private String hmsMeetingUrl;

    // Active Coding Challenge
    @Column(name = "problem_id")
    private Long problemId;

    @Column(name = "problem_title")
    private String problemTitle;

    @Column(name = "problem_difficulty", length = 32)
    private String problemDifficulty;

    @Column(name = "problem_description", columnDefinition = "TEXT")
    private String problemDescription;

    @Column(name = "code_language", length = 32)
    private String codeLanguage = "java";

    @Column(name = "submitted_code", columnDefinition = "TEXT")
    private String submittedCode;

    // Interviewer Evaluation Rubric
    @Column(name = "problem_solving_score")
    private Integer problemSolvingScore;

    @Column(name = "technical_competency_score")
    private Integer technicalCompetencyScore;

    @Column(name = "code_quality_score")
    private Integer codeQualityScore;

    @Column(name = "communication_score")
    private Integer communicationScore;

    /** STRONG_HIRE, HIRE, LEAN_HIRE, LEAN_REJECT, REJECT */
    @Column(name = "hiring_decision", length = 32)
    private String hiringDecision;

    @Column(name = "interviewer_notes", columnDefinition = "TEXT")
    private String interviewerNotes;

    @Column(name = "candidate_notes", columnDefinition = "TEXT")
    private String candidateNotes;
}
