package com.institute.lms.entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.NoArgsConstructor;
import lombok.ToString;

import java.util.ArrayList;
import java.util.List;

/**
 * One question on an in-app question paper, belonging to either an assignment
 * or an exam (see {@link AssessmentType}).
 *
 * <p>Options are owned by the question: saving a question saves its options,
 * and removing an option from {@link #options} deletes the row. That lets the
 * admin portal PUT a whole edited question — text, options, correct flags — as
 * a single payload instead of diffing options client-side.
 */
@Entity
@Table(name = "assessment_questions")
@Data
@NoArgsConstructor
@EqualsAndHashCode(callSuper = true, exclude = "options")
@ToString(exclude = "options")
public class AssessmentQuestion extends BaseEntity {

    @Enumerated(EnumType.STRING)
    @Column(name = "assessment_type", nullable = false, length = 20)
    private AssessmentType assessmentType;

    @Column(name = "assessment_id", nullable = false)
    private Long assessmentId;

    @Column(name = "question_text", nullable = false, columnDefinition = "TEXT")
    private String questionText;

    /** Drives radio buttons vs checkboxes on the student side. */
    @Enumerated(EnumType.STRING)
    @Column(name = "question_type", nullable = false, length = 30)
    private QuestionType questionType = QuestionType.SINGLE_CHOICE;

    /** Shown to the student only after they submit, alongside the correct answer. */
    @Column(columnDefinition = "TEXT")
    private String explanation;

    @Column(nullable = false)
    private Integer marks = 1;

    @Column(name = "display_order", nullable = false)
    private Integer displayOrder = 0;

    /**
     * Reference answer for FILL_IN_BLANK (exact-match string) or optional non-graded
     * notes for CODING. Never sent to students pre-submission — same rule as
     * {@code isCorrect} on options today.
     */
    @Column(name = "answer_text", columnDefinition = "TEXT")
    private String answerText;

    @Column(name = "coding_starter_java", columnDefinition = "TEXT")
    private String codingStarterJava;

    @Column(name = "coding_starter_python", columnDefinition = "TEXT")
    private String codingStarterPython;

    @Column(name = "coding_constraints", columnDefinition = "TEXT")
    private String codingConstraints;

    @Column(name = "coding_input_format", columnDefinition = "TEXT")
    private String codingInputFormat;

    @Column(name = "coding_output_format", columnDefinition = "TEXT")
    private String codingOutputFormat;

    @Column(name = "coding_difficulty", length = 20)
    private String codingDifficulty = "MEDIUM";

    @Column(name = "coding_title", length = 255)
    private String codingTitle;

    @JsonIgnore
    @OneToMany(mappedBy = "question", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.EAGER)
    @OrderBy("displayOrder ASC, id ASC")
    private List<AssessmentQuestionOption> options = new ArrayList<>();

    @JsonIgnore
    @OneToMany(mappedBy = "question", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    @OrderBy("displayOrder ASC, id ASC")
    private List<CodingTestCase> testCases = new ArrayList<>();

    /** Keeps both sides of the relation consistent so the FK is populated on insert. */
    public void addOption(AssessmentQuestionOption option) {
        option.setQuestion(this);
        this.options.add(option);
    }

    public void clearOptions() {
        this.options.clear();
    }

    public void addTestCase(CodingTestCase testCase) {
        testCase.setQuestion(this);
        if (testCase.getOrganizationId() == null) {
            testCase.setOrganizationId(this.getOrganizationId());
        }
        this.testCases.add(testCase);
    }

    public void clearTestCases() {
        this.testCases.clear();
    }


    public enum QuestionType {
        /** Exactly one correct option — rendered as radio buttons. */
        SINGLE_CHOICE,
        /** One or more correct options — rendered as checkboxes. */
        MULTIPLE_ANSWER,
        /** Student types a short answer, graded by exact string match against {@link #answerText}. */
        FILL_IN_BLANK,
        /** Student types a free-form answer; not auto-graded (no execution sandbox). */
        CODING
    }
}
