package com.institute.lms.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "exam_results")
@Data
@NoArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class ExamResult extends BaseEntity {
    
    @Column(name = "user_id", nullable = false)
    private Long userId;
    
    @Column(name = "exam_id", nullable = false)
    private Long examId;
    
    @Column(name = "marks_obtained")
    private Integer marksObtained;
    
    @Column(name = "total_marks")
    private Integer totalMarks;
    
    @Column(name = "percentage")
    private Double percentage;
    
    @Column(name = "status")
    private String status; // PASSED, FAILED, etc.
}