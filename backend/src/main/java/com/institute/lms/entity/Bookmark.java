package com.institute.lms.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.NoArgsConstructor;
import java.time.LocalDateTime;

@Entity
@Table(name = "bookmarks")
@Data
@NoArgsConstructor
@EqualsAndHashCode(callSuper = true, exclude = {"user", "lesson"})
public class Bookmark extends BaseEntity {
    @ManyToOne
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne
    @JoinColumn(name = "lesson_id", nullable = false)
    private Lesson lesson;

    @Column(name = "bookmarked_at")
    private LocalDateTime bookmarkedAt;
}