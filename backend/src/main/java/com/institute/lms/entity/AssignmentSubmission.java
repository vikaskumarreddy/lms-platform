package com.institute.lms.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Entity
@Table(name = "assignment_submissions")
@Data
@NoArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class AssignmentSubmission extends BaseEntity {
    
    @ManyToOne
    @JoinColumn(name = "user_id", nullable = false)
    private User user;
    
    @Column(name = "assignment_id", nullable = false)
    private Long assignmentId;
    
    @Column(columnDefinition = "TEXT")
    private String submission;
    
    @Column(name = "submitted_at")
    private LocalDateTime submittedAt;
    
    @Column(name = "marks_obtained")
    private Integer marksObtained;
    
    @Column(columnDefinition = "TEXT")
    private String feedback;
    
    @Column(name = "is_graded")
    private Boolean isGraded = false;
}