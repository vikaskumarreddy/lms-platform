package com.institute.lms.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Entity
@Table(name = "exam_submissions")
@Data
@NoArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class ExamSubmission extends BaseEntity {
    
    @ManyToOne
    @JoinColumn(name = "user_id", nullable = false)
    private User user;
    
    @Column(name = "exam_id", nullable = false)
    private Long examId;
    
    @Column(columnDefinition = "TEXT")
    private String answers;
    
    @Column(name = "submitted_at")
    private LocalDateTime submittedAt;
    
    @Column(name = "marks_obtained")
    private Integer marksObtained;
    
    @Column(columnDefinition = "TEXT")
    private String remarks;
    
    @Column(name = "is_graded")
    private Boolean isGraded = false;
}