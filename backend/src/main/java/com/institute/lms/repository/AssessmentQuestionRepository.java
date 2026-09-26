package com.institute.lms.repository;

import com.institute.lms.entity.AssessmentQuestion;
import com.institute.lms.entity.AssessmentType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface AssessmentQuestionRepository extends JpaRepository<AssessmentQuestion, Long> {

    List<AssessmentQuestion> findByAssessmentTypeAndAssessmentIdOrderByDisplayOrderAscIdAsc(
            AssessmentType assessmentType, Long assessmentId);

    long countByAssessmentTypeAndAssessmentId(AssessmentType assessmentType, Long assessmentId);

    void deleteByAssessmentTypeAndAssessmentId(AssessmentType assessmentType, Long assessmentId);

    /**
     * Question count per assessment, so the admin tables can badge every row from one
     * request instead of one request per row. JPQL, so the tenant discriminator still applies.
     */
    @Query("SELECT q.assessmentId, COUNT(q) FROM AssessmentQuestion q "
            + "WHERE q.assessmentType = :type GROUP BY q.assessmentId")
    List<Object[]> countsByType(@Param("type") AssessmentType type);

    List<AssessmentQuestion> findByQuestionType(AssessmentQuestion.QuestionType questionType);

    @Query("SELECT q FROM AssessmentQuestion q WHERE q.questionType = :questionType AND (q.assessmentId = 0 OR q.assessmentId IS NULL OR q.assessmentType = com.institute.lms.entity.AssessmentType.PRACTICE) ORDER BY q.id DESC")
    List<AssessmentQuestion> findCodingBankQuestions(@Param("questionType") AssessmentQuestion.QuestionType questionType);
}

