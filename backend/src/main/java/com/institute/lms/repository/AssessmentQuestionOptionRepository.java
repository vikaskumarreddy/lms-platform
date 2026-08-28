package com.institute.lms.repository;

import com.institute.lms.entity.AssessmentQuestionOption;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface AssessmentQuestionOptionRepository extends JpaRepository<AssessmentQuestionOption, Long> {
}
