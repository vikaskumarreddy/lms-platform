package com.institute.lms.repository;

import com.institute.lms.entity.AssessmentResponse;
import com.institute.lms.entity.AssessmentType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface AssessmentResponseRepository extends JpaRepository<AssessmentResponse, Long> {

    List<AssessmentResponse> findByAssessmentTypeAndAssessmentId(AssessmentType assessmentType, Long assessmentId);

    List<AssessmentResponse> findByAssessmentTypeAndAssessmentIdAndUserId(
            AssessmentType assessmentType, Long assessmentId, Long userId);

    void deleteByAssessmentTypeAndAssessmentIdAndUserId(
            AssessmentType assessmentType, Long assessmentId, Long userId);

    void deleteByAssessmentTypeAndAssessmentId(AssessmentType assessmentType, Long assessmentId);

    void deleteByQuestionId(Long questionId);
}
