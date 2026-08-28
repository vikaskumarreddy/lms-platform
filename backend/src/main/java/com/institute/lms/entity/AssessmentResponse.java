package com.institute.lms.entity;

import com.institute.lms.converter.LongListConverter;
import jakarta.persistence.*;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.NoArgsConstructor;

import java.util.ArrayList;
import java.util.List;

/**
 * What one student picked for one question, plus what the auto-grader made of it.
 *
 * <p>Kept relational rather than as a JSON blob on the submission so a mentor can
 * open an individual student and see the exact options chosen, and so per-question
 * batch analytics ("everyone missed Q4") are a plain SQL group-by.
 */
@Entity
@Table(name = "assessment_responses")
@Data
@NoArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class AssessmentResponse extends BaseEntity {

    @Enumerated(EnumType.STRING)
    @Column(name = "assessment_type", nullable = false, length = 20)
    private AssessmentType assessmentType;

    @Column(name = "assessment_id", nullable = false)
    private Long assessmentId;

    /** The assignment_submissions / exam_submissions row this attempt produced. */
    @Column(name = "submission_id")
    private Long submissionId;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "question_id", nullable = false)
    private Long questionId;

    /** Comma-separated option ids, same storage convention as {@code batch_ids}. */
    @Column(name = "selected_option_ids", length = 512)
    @Convert(converter = LongListConverter.class)
    private List<Long> selectedOptionIds = new ArrayList<>();

    @Column(name = "is_correct", nullable = false)
    private Boolean isCorrect = false;

    @Column(name = "marks_awarded", nullable = false)
    private Integer marksAwarded = 0;
}
