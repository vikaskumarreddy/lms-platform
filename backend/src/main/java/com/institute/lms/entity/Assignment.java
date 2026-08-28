package com.institute.lms.entity;

import com.institute.lms.converter.LongListConverter;
import jakarta.persistence.*;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.List;

@Entity
@Table(name = "assignments")
@Data
@NoArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class Assignment extends BaseEntity {
    
    @Column(nullable = false)
    private String title;
    
    @Column(columnDefinition = "TEXT")
    private String description;
    
    @Column(name = "due_date")
    private LocalDateTime dueDate;
    
    @Column(name = "total_marks")
    private Integer totalMarks;
    
    @Column(name = "batch_ids")
    @Convert(converter = LongListConverter.class)
    private List<Long> batchIds;
    
    @Column(name = "course_id")
    private Long courseId;
    
    @Column(name = "is_active")
    private Boolean isActive = true;
    
    @Column(name = "link")
    private String link;

    /**
     * WEB publishes {@link #link} for the embedded browser; IN_APP means the
     * question paper authored in the admin portal is answered inside the app.
     */
    @Enumerated(EnumType.STRING)
    @Column(name = "delivery_mode", nullable = false, length = 20)
    private DeliveryMode deliveryMode = DeliveryMode.WEB;
}
