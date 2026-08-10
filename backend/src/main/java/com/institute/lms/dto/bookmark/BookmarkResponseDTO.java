package com.institute.lms.dto.bookmark;

import com.fasterxml.jackson.annotation.JsonFormat;
import lombok.Data;

import java.time.LocalDateTime;

@Data
public class BookmarkResponseDTO {
    private Long id;
    private Long lessonId;
    private String lessonTitle;
    private String lessonType;
    private String courseName;
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm")
    private LocalDateTime bookmarkedAt;
}