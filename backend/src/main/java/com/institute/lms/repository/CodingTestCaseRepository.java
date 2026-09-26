package com.institute.lms.repository;

import com.institute.lms.entity.CodingTestCase;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface CodingTestCaseRepository extends JpaRepository<CodingTestCase, Long> {
    List<CodingTestCase> findByQuestionIdOrderByDisplayOrderAscIdAsc(Long questionId);
    List<CodingTestCase> findByQuestionIdAndIsSampleTrueOrderByDisplayOrderAscIdAsc(Long questionId);
    void deleteByQuestionId(Long questionId);
}
