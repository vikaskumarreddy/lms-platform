package com.institute.lms.dto.feedback;

import com.fasterxml.jackson.annotation.JsonFormat;
import lombok.Data;

import java.time.LocalDateTime;

@Data
public class FeedbackResponseDTO {
    private Long id;
    private Long userId;
    private String studentName;
    private Long courseId;
    private String courseName;
    private String type;
    private Integer rating;
    private String comment;
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm")
    private LocalDateTime createdAt;
}
