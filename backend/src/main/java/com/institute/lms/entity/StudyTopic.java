package com.institute.lms.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.Data;
import lombok.EqualsAndHashCode;

/** A student's personal study topic, separate from official course lessons. */
@Entity
@Table(name = "study_topics")
@Data
@EqualsAndHashCode(callSuper = true)
public class StudyTopic extends BaseEntity {
    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(nullable = false, length = 200)
    private String title;
}
