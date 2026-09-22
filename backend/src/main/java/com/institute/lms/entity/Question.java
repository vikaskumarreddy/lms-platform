package com.institute.lms.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.NoArgsConstructor;

import java.util.Set;

@Entity
@Table(name = "questions")
@Data
@NoArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class Question extends BaseEntity {

    @Column(nullable = false)
    private String title;

    @Column(columnDefinition = "TEXT")
    private String content;

    @Column(name = "category")
    private String category;

    @Column(name = "author_name")
    private String authorName;

    @Column(name = "is_answered")
    private Boolean isAnswered = false;

    @Column(name = "answer_count")
    private Integer answerCount = 0;

    @Column(name = "view_count")
    private Integer viewCount = 0;

    @Column(name = "vote_count")
    private Integer voteCount = 0;

    @Column(name = "plan_id")
    private Long planId;

    @Column(name = "batch_id")
    private Long batchId;

    @Column(name = "user_id")
    private Long userId;

    @Column(name = "is_escalated")
    private Boolean isEscalated = false;

    @Column(name = "is_ai_answered")
    private Boolean isAiAnswered = false;

    @com.fasterxml.jackson.annotation.JsonIgnore
    @OneToMany(mappedBy = "question", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    private Set<Answer> answers;
}