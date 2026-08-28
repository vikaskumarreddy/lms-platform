package com.institute.lms.entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.NoArgsConstructor;
import lombok.ToString;

/**
 * A single selectable option on an {@link AssessmentQuestion}.
 *
 * <p>{@link #isCorrect} is deliberately never serialised to students — the
 * student-facing paper endpoint builds its own response map that omits it, so
 * the answer key cannot be read out of the API before submitting.
 */
@Entity
@Table(name = "assessment_question_options")
@Data
@NoArgsConstructor
@EqualsAndHashCode(callSuper = true, exclude = "question")
@ToString(exclude = "question")
public class AssessmentQuestionOption extends BaseEntity {

    @JsonIgnore
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "question_id", nullable = false)
    private AssessmentQuestion question;

    @Column(name = "option_text", nullable = false, columnDefinition = "TEXT")
    private String optionText;

    @Column(name = "is_correct", nullable = false)
    private Boolean isCorrect = false;

    @Column(name = "display_order", nullable = false)
    private Integer displayOrder = 0;
}
