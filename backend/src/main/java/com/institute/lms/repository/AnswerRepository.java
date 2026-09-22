package com.institute.lms.repository;

import com.institute.lms.entity.Answer;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface AnswerRepository extends JpaRepository<Answer, Long> {
    @Query("SELECT a FROM Answer a WHERE a.question.id = :questionId ORDER BY a.createdAt ASC")
    List<Answer> findByQuestionId(@Param("questionId") Long questionId);
}