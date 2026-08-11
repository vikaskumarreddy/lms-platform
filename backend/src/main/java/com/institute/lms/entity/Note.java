package com.institute.lms.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "notes")
@Data
@NoArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class Note extends BaseEntity {

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "lesson_id")
    private Long lessonId;

    @Column(nullable = false)
    private String title = "Untitled Note";

    @Column(columnDefinition = "TEXT")
    private String content;
}
