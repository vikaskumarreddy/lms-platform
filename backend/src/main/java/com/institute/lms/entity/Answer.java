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

    @ManyToOne
    @JoinColumn(name = "question_id", nullable = false)
    private Question question;

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
}