package com.institute.lms.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "answers")
@Data
@NoArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class Answer extends BaseEntity {

    @com.fasterxml.jackson.annotation.JsonIgnore
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "question_id", nullable = false)
    private Question question;

    @com.fasterxml.jackson.annotation.JsonProperty("questionId")
    public Long getQuestionId() {
        return question != null ? question.getId() : null;
    }

    @Column(columnDefinition = "TEXT", nullable = false)
    private String content;

    @Column(name = "author_name")
    private String authorName;

    @Column(name = "is_accepted")
    private Boolean isAccepted = false;

    @Column(name = "vote_count")
    private Integer voteCount = 0;

    @Column(name = "user_id")
    private Long userId;

    @Column(name = "is_ai_generated")
    private Boolean isAiGenerated = false;
}