package com.institute.lms.controller;

import com.institute.lms.entity.Answer;
import com.institute.lms.entity.Question;
import com.institute.lms.repository.AnswerRepository;
import com.institute.lms.repository.QuestionRepository;
import com.institute.lms.repository.UserRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@RestController
@RequestMapping("/api/questions")
public class QuestionController {

    private final QuestionRepository questionRepository;
    private final AnswerRepository answerRepository;
    private final UserRepository userRepository;

    public QuestionController(QuestionRepository questionRepository,
                              AnswerRepository answerRepository,
                              UserRepository userRepository) {
        this.questionRepository = questionRepository;
        this.answerRepository = answerRepository;
                this.userRepository = userRepository;
    }

    @GetMapping
    public List<Question> getAllQuestions() {
        return questionRepository.findAll();
    }

    @GetMapping("/{id}")
    public ResponseEntity<Question> getQuestionById(@PathVariable Long id) {
        return questionRepository.findById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @GetMapping("/batch/{batchId}")
    public List<Question> getQuestionsByBatch(@PathVariable Long batchId) {
        // Includes both batch-specific questions and "All Batches" questions (batchId == null).
        return questionRepository.findVisibleToBatch(batchId);
    }

    @GetMapping("/user/{userId}")
    public List<Question> getQuestionsByUser(@PathVariable Long userId) {
        return questionRepository.findByUserId(userId);
    }

    @GetMapping("/category/{category}")
    public List<Question> getQuestionsByCategory(@PathVariable String category) {
        return questionRepository.findByCategoryIgnoreCase(category);
    }

    @GetMapping("/{id}/answers")
    public List<Answer> getAnswersByQuestion(@PathVariable Long id) {
                return answerRepository.findByQuestionId(id);
    }

    @PostMapping
    public ResponseEntity<Question> createQuestion(@RequestBody Question question) {
        if (question.getIsAnswered() == null) question.setIsAnswered(false);
        if (question.getAnswerCount() == null) question.setAnswerCount(0);
        if (question.getViewCount() == null) question.setViewCount(0);
        if (question.getVoteCount() == null) question.setVoteCount(0);
        Question saved = questionRepository.save(question);
        return ResponseEntity.ok(saved);
    }

    @PutMapping("/{id}")
    public ResponseEntity<Question> updateQuestion(@PathVariable Long id, @RequestBody Question question) {
        return questionRepository.findById(id)
                .map(existing -> {
                    existing.setTitle(question.getTitle());
                    existing.setContent(question.getContent());
                    existing.setCategory(question.getCategory());
                    existing.setAuthorName(question.getAuthorName());
                    existing.setIsAnswered(question.getIsAnswered());
                    existing.setAnswerCount(question.getAnswerCount());
                    existing.setViewCount(question.getViewCount());
                    existing.setVoteCount(question.getVoteCount());
                    existing.setPlanId(question.getPlanId());
                    existing.setBatchId(question.getBatchId());
                    existing.setUserId(question.getUserId());
                    return ResponseEntity.ok(questionRepository.save(existing));
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteQuestion(@PathVariable Long id) {
        questionRepository.deleteById(id);
                return ResponseEntity.ok().build();
    }

    @PostMapping("/{id}/answers")
    public ResponseEntity<Answer> createAnswer(@PathVariable Long id, @RequestBody Answer answer) {
        return questionRepository.findById(id)
                .map(question -> {
                    answer.setQuestion(question);
                    if (answer.getIsAccepted() == null) answer.setIsAccepted(false);
                    if (answer.getVoteCount() == null) answer.setVoteCount(0);
                    Answer saved = answerRepository.save(answer);

                    question.setAnswerCount((question.getAnswerCount() == null ? 0 : question.getAnswerCount()) + 1);
                    question.setIsAnswered(true);
                    questionRepository.save(question);

                    return ResponseEntity.ok(saved);
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @PutMapping("/answers/{id}")
    public ResponseEntity<Answer> updateAnswer(@PathVariable Long id, @RequestBody Answer answer) {
        return answerRepository.findById(id)
                .map(existing -> {
                    existing.setContent(answer.getContent());
                    existing.setAuthorName(answer.getAuthorName());
                    existing.setIsAccepted(answer.getIsAccepted());
                    existing.setVoteCount(answer.getVoteCount());
                    return ResponseEntity.ok(answerRepository.save(existing));
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/answers/{id}")
    public ResponseEntity<Void> deleteAnswer(@PathVariable Long id) {
        Answer answer = answerRepository.findById(id).orElse(null);
        if (answer != null) {
            Question question = answer.getQuestion();
            if (question != null && question.getAnswerCount() != null && question.getAnswerCount() > 0) {
                question.setAnswerCount(question.getAnswerCount() - 1);
                questionRepository.save(question);
            }
            answerRepository.deleteById(id);
        }
                return ResponseEntity.ok().build();
    }

    @PostMapping("/{id}/vote")
    public ResponseEntity<Question> voteQuestion(@PathVariable Long id, @RequestParam(defaultValue = "up") String direction) {
        return questionRepository.findById(id)
                .map(question -> {
                    Integer currentVotes = question.getVoteCount() == null ? 0 : question.getVoteCount();
                    question.setVoteCount("up".equals(direction) ? currentVotes + 1 : Math.max(0, currentVotes - 1));
                    return ResponseEntity.ok(questionRepository.save(question));
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping("/answers/{id}/vote")
    public ResponseEntity<Answer> voteAnswer(@PathVariable Long id, @RequestParam(defaultValue = "up") String direction) {
        return answerRepository.findById(id)
                .map(answer -> {
                    Integer currentVotes = answer.getVoteCount() == null ? 0 : answer.getVoteCount();
                    answer.setVoteCount("up".equals(direction) ? currentVotes + 1 : Math.max(0, currentVotes - 1));
                    return ResponseEntity.ok(answerRepository.save(answer));
                })
                .orElse(ResponseEntity.notFound().build());
    }
}