package com.institute.lms.entity;

import com.institute.lms.converter.LongListConverter;
import jakarta.persistence.*;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.List;

@Entity
@Table(name = "exams")
@Data
@NoArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class Exam extends BaseEntity {
    
    @Column(nullable = false)
    private String title;
    
    @Column(columnDefinition = "TEXT")
    private String description;
    
    @Column(name = "exam_date")
    private LocalDateTime examDate;
    
    @Column(name = "duration_minutes")
    private Integer durationMinutes;
    
    @Column(name = "total_marks")
    private Integer totalMarks;
    
    @Column(name = "passing_marks")
    private Integer passingMarks;
    
    @Column(name = "batch_ids")
    @Convert(converter = LongListConverter.class)
    private List<Long> batchIds;
    
    @Column(name = "course_id")
    private Long courseId;
    
    @Column(name = "is_active")
    private Boolean isActive = true;
    
    @Column(name = "link")
    private String link;
}