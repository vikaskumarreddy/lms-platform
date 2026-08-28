package com.institute.lms.service;

import com.institute.lms.entity.*;
import com.institute.lms.repository.*;
import com.institute.lms.service.subscription.ActivityMeterService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;

/**
 * Authoring, delivery and automatic grading of in-app question papers.
 *
 * <p>A "paper" is the ordered list of {@link AssessmentQuestion}s attached to an
 * assignment or an exam whose {@code deliveryMode} is {@link DeliveryMode#IN_APP}.
 * WEB assessments have no paper - the mobile app just opens their {@code link}.</p>
 *
 * <p>Grading is fully automatic: a question is correct only when the student
 * selection is exactly the set of options flagged {@code isCorrect} (no partial
 * credit, and no credit for picking every option on a multiple-answer question).
 * The resulting marks are written straight onto the assignment/exam submission and
 * the submission is flagged graded, so mentors never have to score these by hand.</p>
 */
@Service
public class AssessmentPaperService {

    private final AssessmentQuestionRepository questionRepository;
    private final AssessmentResponseRepository responseRepository;
    private final AssignmentSubmissionRepository assignmentSubmissionRepository;
    private final ExamSubmissionRepository examSubmissionRepository;
    private final UserRepository userRepository;
    private final ActivityMeterService activityMeter;

    public AssessmentPaperService(AssessmentQuestionRepository questionRepository,
                                  AssessmentResponseRepository responseRepository,
                                  AssignmentSubmissionRepository assignmentSubmissionRepository,
                                  ExamSubmissionRepository examSubmissionRepository,
                                  UserRepository userRepository,
                                  ActivityMeterService activityMeter) {
        this.questionRepository = questionRepository;
        this.responseRepository = responseRepository;
        this.assignmentSubmissionRepository = assignmentSubmissionRepository;
        this.examSubmissionRepository = examSubmissionRepository;
        this.userRepository = userRepository;
        this.activityMeter = activityMeter;
    }

    // ------------------------------------------------------------------ authoring

    public List<AssessmentQuestion> questions(AssessmentType type, Long assessmentId) {
        return questionRepository.findByAssessmentTypeAndAssessmentIdOrderByDisplayOrderAscIdAsc(type, assessmentId);
    }

    public long questionCount(AssessmentType type, Long assessmentId) {
        return questionRepository.countByAssessmentTypeAndAssessmentId(type, assessmentId);
    }

    /** Sum of every question mark value - what the paper is actually out of. */
    public int paperMarks(AssessmentType type, Long assessmentId) {
        return questions(type, assessmentId).stream()
                .mapToInt(q -> q.getMarks() == null ? 0 : q.getMarks())
                .sum();
    }

    @Transactional
    public AssessmentQuestion createQuestion(AssessmentType type, Long assessmentId, QuestionForm form) {
        AssessmentQuestion question = new AssessmentQuestion();
        question.setAssessmentType(type);
        question.setAssessmentId(assessmentId);
        if (form.displayOrder == null) {
            question.setDisplayOrder((int) questionCount(type, assessmentId));
        }
        apply(question, form);
        return questionRepository.save(question);
    }

    @Transactional
    public AssessmentQuestion updateQuestion(Long questionId, QuestionForm form) {
        AssessmentQuestion question = questionRepository.findById(questionId)
                .orElseThrow(() -> new IllegalArgumentException("Question not found: " + questionId));
        apply(question, form);
        return questionRepository.save(question);
    }

    @Transactional
    public void deleteQuestion(Long questionId) {
        // Responses point at questions by id (no FK, because the paper is polymorphic),
        // so orphaned answers have to be swept explicitly.
        responseRepository.deleteByQuestionId(questionId);
        questionRepository.deleteById(questionId);
    }

    /** Persists a new question order; ids not in the list keep their current position. */
    @Transactional
    public void reorder(AssessmentType type, Long assessmentId, List<Long> orderedIds) {
        Map<Long, AssessmentQuestion> byId = questions(type, assessmentId).stream()
                .collect(Collectors.toMap(AssessmentQuestion::getId, q -> q));
        int order = 0;
        for (Long id : orderedIds) {
            AssessmentQuestion question = byId.get(id);
            if (question != null) {
                question.setDisplayOrder(order++);
                questionRepository.save(question);
            }
        }
    }

    /** Removes a whole paper - called when the parent assignment/exam is deleted. */
    @Transactional
    public void deletePaper(AssessmentType type, Long assessmentId) {
        responseRepository.deleteByAssessmentTypeAndAssessmentId(type, assessmentId);
        questionRepository.deleteByAssessmentTypeAndAssessmentId(type, assessmentId);
    }

    private void apply(AssessmentQuestion question, QuestionForm form) {
        question.setQuestionText(form.questionText);
        question.setExplanation(form.explanation);
        question.setQuestionType(form.questionType == null
                ? AssessmentQuestion.QuestionType.SINGLE_CHOICE : form.questionType);
        question.setMarks(form.marks == null || form.marks < 1 ? 1 : form.marks);
        if (form.displayOrder != null) question.setDisplayOrder(form.displayOrder);

        question.clearOptions();
        int order = 0;
        List<OptionForm> incoming = form.options == null ? Collections.emptyList() : form.options;
        for (OptionForm optionForm : incoming) {
            if (optionForm.optionText == null || optionForm.optionText.isBlank()) continue;
            AssessmentQuestionOption option = new AssessmentQuestionOption();
            option.setOptionText(optionForm.optionText.trim());
            option.setIsCorrect(Boolean.TRUE.equals(optionForm.isCorrect));
            option.setDisplayOrder(order++);
            question.addOption(option);
        }
    }

    // ------------------------------------------------------------------ delivery

    /**
     * The student-facing paper. Deliberately builds its own maps instead of returning
     * entities: {@code isCorrect} must never reach the device before submission, or the
     * answer key can simply be read out of the network response.
     */
    public List<Map<String, Object>> studentPaper(AssessmentType type, Long assessmentId) {
        return questions(type, assessmentId).stream().map(q -> {
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("id", q.getId());
            item.put("questionText", q.getQuestionText());
            item.put("questionType", q.getQuestionType().name());
            item.put("marks", q.getMarks());
            item.put("displayOrder", q.getDisplayOrder());
            item.put("options", q.getOptions().stream().map(o -> {
                Map<String, Object> opt = new LinkedHashMap<>();
                opt.put("id", o.getId());
                opt.put("optionText", o.getOptionText());
                return opt;
            }).collect(Collectors.toList()));
            return item;
        }).collect(Collectors.toList());
    }

    /** Full question payload including the answer key - admin/mentor/review use only. */
    public List<Map<String, Object>> answerKey(AssessmentType type, Long assessmentId) {
        return questions(type, assessmentId).stream().map(this::withKey).collect(Collectors.toList());
    }

    private Map<String, Object> withKey(AssessmentQuestion q) {
        Map<String, Object> item = new LinkedHashMap<>();
        item.put("id", q.getId());
        item.put("questionText", q.getQuestionText());
        item.put("questionType", q.getQuestionType().name());
        item.put("explanation", q.getExplanation());
        item.put("marks", q.getMarks());
        item.put("displayOrder", q.getDisplayOrder());
        item.put("options", q.getOptions().stream().map(o -> {
            Map<String, Object> opt = new LinkedHashMap<>();
            opt.put("id", o.getId());
            opt.put("optionText", o.getOptionText());
            opt.put("isCorrect", Boolean.TRUE.equals(o.getIsCorrect()));
            opt.put("displayOrder", o.getDisplayOrder());
            return opt;
        }).collect(Collectors.toList()));
        return item;
    }

    public boolean hasSubmitted(AssessmentType type, Long assessmentId, Long userId) {
        return type == AssessmentType.ASSIGNMENT
                ? assignmentSubmissionRepository.findByUserIdAndAssignmentId(userId, assessmentId).isPresent()
                : examSubmissionRepository.findByUserIdAndExamId(userId, assessmentId).isPresent();
    }

    // ------------------------------------------------------------------ grading

    /**
     * Grades an attempt, stores one {@link AssessmentResponse} per question so mentors
     * can see exactly which options the student picked, and writes the score back onto
     * the assignment/exam submission.
     */
    @Transactional
    public Map<String, Object> submitAttempt(AssessmentType type, Long assessmentId, Long userId,
                                             List<AnswerForm> answers, Integer timeTakenSeconds) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("User not found: " + userId));

        List<AssessmentQuestion> paper = questions(type, assessmentId);
        if (paper.isEmpty()) throw new IllegalStateException("This assessment has no question paper yet");

        Map<Long, List<Long>> selectionsByQuestion = new HashMap<>();
        if (answers != null) {
            for (AnswerForm answer : answers) {
                if (answer.questionId == null) continue;
                selectionsByQuestion.put(answer.questionId,
                        answer.selectedOptionIds == null ? Collections.emptyList() : answer.selectedOptionIds);
            }
        }

        // A re-attempt overwrites the previous answers rather than appending to them.
        responseRepository.deleteByAssessmentTypeAndAssessmentIdAndUserId(type, assessmentId, userId);

        int totalMarks = 0;
        int scored = 0;
        int correctCount = 0;
        List<Map<String, Object>> perQuestion = new ArrayList<>();

        for (AssessmentQuestion question : paper) {
            int questionMarks = question.getMarks() == null ? 1 : question.getMarks();
            totalMarks += questionMarks;

            Set<Long> correctIds = question.getOptions().stream()
                    .filter(o -> Boolean.TRUE.equals(o.getIsCorrect()))
                    .map(AssessmentQuestionOption::getId)
                    .collect(Collectors.toCollection(LinkedHashSet::new));

            List<Long> selectedRaw = selectionsByQuestion.getOrDefault(question.getId(), Collections.emptyList());
            Set<Long> validOptionIds = question.getOptions().stream()
                    .map(AssessmentQuestionOption::getId).collect(Collectors.toSet());
            List<Long> selected = selectedRaw.stream()
                    .filter(Objects::nonNull)
                    .filter(validOptionIds::contains)
                    .distinct()
                    .collect(Collectors.toList());

            // Exact-set match: every correct option picked, nothing extra.
            boolean correct = !correctIds.isEmpty() && correctIds.equals(new HashSet<>(selected));
            int awarded = correct ? questionMarks : 0;
            scored += awarded;
            if (correct) correctCount++;

            AssessmentResponse response = new AssessmentResponse();
            response.setAssessmentType(type);
            response.setAssessmentId(assessmentId);
            response.setUserId(userId);
            response.setQuestionId(question.getId());
            response.setSelectedOptionIds(new ArrayList<>(selected));
            response.setIsCorrect(correct);
            response.setMarksAwarded(awarded);
            responseRepository.save(response);

            Map<String, Object> review = withKey(question);
            review.put("selectedOptionIds", selected);
            review.put("isCorrect", correct);
            review.put("marksAwarded", awarded);
            perQuestion.add(review);
        }

        Long submissionId = persistSubmission(type, assessmentId, user, scored, totalMarks,
                correctCount, paper.size(), timeTakenSeconds);

        // Back-fill the submission id so mentor views can join responses to a submission.
        List<AssessmentResponse> saved =
                responseRepository.findByAssessmentTypeAndAssessmentIdAndUserId(type, assessmentId, userId);
        saved.forEach(r -> r.setSubmissionId(submissionId));
        responseRepository.saveAll(saved);

        if (user.getRole() != null && "STUDENT".equalsIgnoreCase(user.getRole().name())) {
            activityMeter.recordAssessmentSubmission(userId);
        }

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("submissionId", submissionId);
        result.put("score", scored);
        result.put("totalMarks", totalMarks);
        result.put("correctCount", correctCount);
        result.put("questionCount", paper.size());
        result.put("percentage", totalMarks == 0 ? 0.0 : Math.round(scored * 1000.0 / totalMarks) / 10.0);
        result.put("submittedAt", LocalDateTime.now());
        result.put("questions", perQuestion);
        return result;
    }

    private Long persistSubmission(AssessmentType type, Long assessmentId, User user, int scored,
                                   int totalMarks, int correctCount, int questionCount,
                                   Integer timeTakenSeconds) {
        String summary = "Auto-graded: " + correctCount + "/" + questionCount + " correct, "
                + scored + "/" + totalMarks + " marks"
                + (timeTakenSeconds != null
                        ? " in " + (timeTakenSeconds / 60) + "m " + (timeTakenSeconds % 60) + "s" : "");

        if (type == AssessmentType.ASSIGNMENT) {
            AssignmentSubmission submission = assignmentSubmissionRepository
                    .findByUserIdAndAssignmentId(user.getId(), assessmentId)
                    .orElseGet(AssignmentSubmission::new);
            submission.setAssignmentId(assessmentId);
            submission.setUser(user);
            submission.setSubmission(summary);
            submission.setSubmittedAt(LocalDateTime.now());
            submission.setMarksObtained(scored);
            submission.setFeedback(summary);
            submission.setIsGraded(true);
            return assignmentSubmissionRepository.save(submission).getId();
        }

        ExamSubmission submission = examSubmissionRepository
                .findByUserIdAndExamId(user.getId(), assessmentId)
                .orElseGet(ExamSubmission::new);
        submission.setExamId(assessmentId);
        submission.setUser(user);
        submission.setAnswers(summary);
        submission.setSubmittedAt(LocalDateTime.now());
        submission.setMarksObtained(scored);
        submission.setRemarks(summary);
        submission.setIsGraded(true);
        return examSubmissionRepository.save(submission).getId();
    }

    // ------------------------------------------------------------------ review / mentor

    /** What a student sees after submitting: their answers, the key, and explanations. */
    public Map<String, Object> review(AssessmentType type, Long assessmentId, Long userId) {
        List<AssessmentQuestion> paper = questions(type, assessmentId);
        Map<Long, AssessmentResponse> byQuestion =
                responseRepository.findByAssessmentTypeAndAssessmentIdAndUserId(type, assessmentId, userId).stream()
                        .collect(Collectors.toMap(AssessmentResponse::getQuestionId, r -> r, (a, b) -> a));

        int scored = 0;
        int totalMarks = 0;
        int correctCount = 0;
        List<Map<String, Object>> items = new ArrayList<>();
        for (AssessmentQuestion question : paper) {
            AssessmentResponse response = byQuestion.get(question.getId());
            Map<String, Object> item = withKey(question);
            item.put("selectedOptionIds",
                    response == null || response.getSelectedOptionIds() == null
                            ? Collections.emptyList() : response.getSelectedOptionIds());
            item.put("isCorrect", response != null && Boolean.TRUE.equals(response.getIsCorrect()));
            item.put("marksAwarded",
                    response == null || response.getMarksAwarded() == null ? 0 : response.getMarksAwarded());
            items.add(item);

            totalMarks += question.getMarks() == null ? 1 : question.getMarks();
            if (response != null) {
                scored += response.getMarksAwarded() == null ? 0 : response.getMarksAwarded();
                if (Boolean.TRUE.equals(response.getIsCorrect())) correctCount++;
            }
        }

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("attempted", !byQuestion.isEmpty());
        result.put("score", scored);
        result.put("totalMarks", totalMarks);
        result.put("correctCount", correctCount);
        result.put("questionCount", paper.size());
        result.put("percentage", totalMarks == 0 ? 0.0 : Math.round(scored * 1000.0 / totalMarks) / 10.0);
        result.put("questions", items);
        return result;
    }

    /**
     * Every student attempt on one paper, each with the exact options that were ticked.
     * This is what lets a mentor see what each individual student chose without any
     * manual marking.
     */
    public Map<String, Object> mentorResponses(AssessmentType type, Long assessmentId) {
        List<AssessmentQuestion> paper = questions(type, assessmentId);

        List<AssessmentResponse> all = responseRepository.findByAssessmentTypeAndAssessmentId(type, assessmentId);
        Map<Long, List<AssessmentResponse>> byUser = all.stream()
                .collect(Collectors.groupingBy(AssessmentResponse::getUserId, LinkedHashMap::new, Collectors.toList()));

        Map<Long, User> users = userRepository.findAllById(byUser.keySet()).stream()
                .collect(Collectors.toMap(User::getId, u -> u));

        int totalMarks = paper.stream().mapToInt(q -> q.getMarks() == null ? 1 : q.getMarks()).sum();

        List<Map<String, Object>> students = new ArrayList<>();
        for (Map.Entry<Long, List<AssessmentResponse>> entry : byUser.entrySet()) {
            User user = users.get(entry.getKey());
            List<AssessmentResponse> responses = entry.getValue();

            int scored = responses.stream().mapToInt(r -> r.getMarksAwarded() == null ? 0 : r.getMarksAwarded()).sum();
            long correct = responses.stream().filter(r -> Boolean.TRUE.equals(r.getIsCorrect())).count();

            List<Map<String, Object>> answers = new ArrayList<>();
            for (AssessmentQuestion question : paper) {
                AssessmentResponse response = responses.stream()
                        .filter(r -> question.getId().equals(r.getQuestionId())).findFirst().orElse(null);
                List<Long> selected = response == null || response.getSelectedOptionIds() == null
                        ? Collections.emptyList() : response.getSelectedOptionIds();

                Map<String, Object> answer = new LinkedHashMap<>();
                answer.put("questionId", question.getId());
                answer.put("questionText", question.getQuestionText());
                answer.put("questionType", question.getQuestionType().name());
                answer.put("marks", question.getMarks());
                answer.put("explanation", question.getExplanation());
                answer.put("selectedOptionIds", selected);
                answer.put("selectedOptions", question.getOptions().stream()
                        .filter(o -> selected.contains(o.getId()))
                        .map(AssessmentQuestionOption::getOptionText).collect(Collectors.toList()));
                answer.put("correctOptions", question.getOptions().stream()
                        .filter(o -> Boolean.TRUE.equals(o.getIsCorrect()))
                        .map(AssessmentQuestionOption::getOptionText).collect(Collectors.toList()));
                answer.put("isCorrect", response != null && Boolean.TRUE.equals(response.getIsCorrect()));
                answer.put("marksAwarded",
                        response == null || response.getMarksAwarded() == null ? 0 : response.getMarksAwarded());
                answer.put("attempted", !selected.isEmpty());
                answers.add(answer);
            }

            Map<String, Object> row = new LinkedHashMap<>();
            row.put("userId", entry.getKey());
            row.put("studentName", user != null ? user.getName() : "Unknown");
            row.put("studentEmail", user != null ? user.getEmail() : null);
            row.put("batchId", user != null ? user.getBatchId() : null);
            row.put("score", scored);
            row.put("totalMarks", totalMarks);
            row.put("correctCount", correct);
            row.put("questionCount", paper.size());
            row.put("percentage", totalMarks == 0 ? 0.0 : Math.round(scored * 1000.0 / totalMarks) / 10.0);
            row.put("answers", answers);
            students.add(row);
        }
        students.sort((a, b) -> Double.compare(
                ((Number) b.get("percentage")).doubleValue(), ((Number) a.get("percentage")).doubleValue()));

        // Per-question difficulty, so a mentor can spot the topic the class fell down on.
        List<Map<String, Object>> analytics = new ArrayList<>();
        for (AssessmentQuestion question : paper) {
            List<AssessmentResponse> forQuestion = all.stream()
                    .filter(r -> question.getId().equals(r.getQuestionId())).collect(Collectors.toList());
            long correct = forQuestion.stream().filter(r -> Boolean.TRUE.equals(r.getIsCorrect())).count();
            Map<String, Object> stat = new LinkedHashMap<>();
            stat.put("questionId", question.getId());
            stat.put("questionText", question.getQuestionText());
            stat.put("attempts", forQuestion.size());
            stat.put("correctCount", correct);
            stat.put("accuracy", forQuestion.isEmpty() ? 0.0
                    : Math.round(correct * 1000.0 / forQuestion.size()) / 10.0);
            analytics.add(stat);
        }

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("questionCount", paper.size());
        result.put("totalMarks", totalMarks);
        result.put("studentCount", students.size());
        result.put("averageScore", students.isEmpty() ? 0.0 : Math.round(students.stream()
                .mapToInt(s -> (Integer) s.get("score")).average().orElse(0) * 100.0) / 100.0);
        result.put("students", students);
        result.put("questionAnalytics", analytics);
        result.put("questions", answerKey(type, assessmentId));
        return result;
    }

    // ------------------------------------------------------------------ request forms

    /** Inbound payload for creating/updating a question (options included). */
    public static class QuestionForm {
        public String questionText;
        public String explanation;
        public AssessmentQuestion.QuestionType questionType;
        public Integer marks;
        public Integer displayOrder;
        public List<OptionForm> options;
    }

    public static class OptionForm {
        public String optionText;
        public Boolean isCorrect;
    }

    /** One student answer inside an attempt. */
    public static class AnswerForm {
        public Long questionId;
        public List<Long> selectedOptionIds;
    }
}
