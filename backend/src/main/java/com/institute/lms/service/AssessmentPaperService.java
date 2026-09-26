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
    private final CodingTestCaseRepository testCaseRepository;

    public AssessmentPaperService(AssessmentQuestionRepository questionRepository,
                                  AssessmentResponseRepository responseRepository,
                                  AssignmentSubmissionRepository assignmentSubmissionRepository,
                                  ExamSubmissionRepository examSubmissionRepository,
                                  UserRepository userRepository,
                                  ActivityMeterService activityMeter,
                                  CodingTestCaseRepository testCaseRepository) {
        this.questionRepository = questionRepository;
        this.responseRepository = responseRepository;
        this.assignmentSubmissionRepository = assignmentSubmissionRepository;
        this.examSubmissionRepository = examSubmissionRepository;
        this.userRepository = userRepository;
        this.activityMeter = activityMeter;
        this.testCaseRepository = testCaseRepository;
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
        AssessmentQuestion saved = questionRepository.save(question);
        applyTestCases(saved, form.testCases);
        return saved;
    }

    @Transactional
    public List<AssessmentQuestion> createQuestionsBulk(AssessmentType type, Long assessmentId, List<QuestionForm> forms) {
        if (forms == null || forms.isEmpty()) {
            return Collections.emptyList();
        }
        int currentCount = (int) questionCount(type, assessmentId);
        List<AssessmentQuestion> savedList = new ArrayList<>();
        for (int i = 0; i < forms.size(); i++) {
            QuestionForm form = forms.get(i);
            AssessmentQuestion question = new AssessmentQuestion();
            question.setAssessmentType(type);
            question.setAssessmentId(assessmentId);
            question.setDisplayOrder(form.displayOrder != null ? form.displayOrder : (currentCount + i));
            apply(question, form);
            AssessmentQuestion saved = questionRepository.save(question);
            applyTestCases(saved, form.testCases);
            savedList.add(saved);
        }
        return savedList;
    }

    @Transactional
    public AssessmentQuestion updateQuestion(Long questionId, QuestionForm form) {
        AssessmentQuestion question = questionRepository.findById(questionId)
                .orElseThrow(() -> new IllegalArgumentException("Question not found: " + questionId));
        apply(question, form);
        AssessmentQuestion saved = questionRepository.save(question);
        applyTestCases(saved, form.testCases);
        return saved;
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
        if (form.codingTitle != null && !form.codingTitle.isBlank()) {
            question.setCodingTitle(form.codingTitle);
        } else if (form.title != null && !form.title.isBlank()) {
            question.setCodingTitle(form.title);
        }
        question.setExplanation(form.explanation);
        question.setQuestionType(form.questionType == null
                ? AssessmentQuestion.QuestionType.SINGLE_CHOICE : form.questionType);
        question.setMarks(form.marks == null || form.marks < 1 ? 1 : form.marks);
        question.setAnswerText(form.answerText);
        if (form.displayOrder != null) question.setDisplayOrder(form.displayOrder);

        question.setCodingStarterJava(form.codingStarterJava);
        question.setCodingStarterPython(form.codingStarterPython);
        question.setCodingConstraints(form.codingConstraints);
        question.setCodingInputFormat(form.codingInputFormat);
        question.setCodingOutputFormat(form.codingOutputFormat);
        if (form.codingDifficulty != null && !form.codingDifficulty.isBlank()) {
            question.setCodingDifficulty(form.codingDifficulty);
        }

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

    private void applyTestCases(AssessmentQuestion question, List<TestCaseForm> testCases) {
        if (question == null || question.getId() == null) return;
        if (testCases != null && !testCases.isEmpty()) {
            testCaseRepository.deleteByQuestionId(question.getId());
            int tcOrder = 0;
            for (TestCaseForm tcForm : testCases) {
                CodingTestCase tc = new CodingTestCase();
                tc.setQuestion(question);
                tc.setOrganizationId(question.getOrganizationId());
                tc.setInput(tcForm.input != null ? tcForm.input : "");
                tc.setExpectedOutput(tcForm.expectedOutput != null ? tcForm.expectedOutput : "");
                tc.setIsSample(Boolean.TRUE.equals(tcForm.isSample));
                tc.setExplanation(tcForm.explanation);
                tc.setDisplayOrder(tcOrder++);
                testCaseRepository.save(tc);
            }
        } else if (question.getQuestionType() == AssessmentQuestion.QuestionType.CODING) {
            copyTestCasesFromBankIfAvailable(question);
        }
    }

    public List<CodingTestCase> copyTestCasesFromBankIfAvailable(AssessmentQuestion question) {
        if (question == null || question.getId() == null) return Collections.emptyList();
        List<AssessmentQuestion> bankQuestions = questionRepository.findCodingBankQuestions(AssessmentQuestion.QuestionType.CODING);
        for (AssessmentQuestion bq : bankQuestions) {
            if (bq.getId().equals(question.getId())) continue;
            boolean matchesTitle = question.getCodingTitle() != null && !question.getCodingTitle().isBlank()
                    && question.getCodingTitle().trim().equalsIgnoreCase(bq.getCodingTitle() != null ? bq.getCodingTitle().trim() : "");
            boolean matchesText = question.getQuestionText() != null && !question.getQuestionText().isBlank()
                    && question.getQuestionText().trim().equalsIgnoreCase(bq.getQuestionText() != null ? bq.getQuestionText().trim() : "");
            if (matchesTitle || matchesText) {
                List<CodingTestCase> bankTcs = testCaseRepository.findByQuestionIdOrderByDisplayOrderAscIdAsc(bq.getId());
                if (!bankTcs.isEmpty()) {
                    List<CodingTestCase> copied = new ArrayList<>();
                    for (CodingTestCase btc : bankTcs) {
                        CodingTestCase tc = new CodingTestCase();
                        tc.setQuestion(question);
                        tc.setOrganizationId(question.getOrganizationId() != null ? question.getOrganizationId() : btc.getOrganizationId());
                        tc.setInput(btc.getInput());
                        tc.setExpectedOutput(btc.getExpectedOutput());
                        tc.setIsSample(btc.getIsSample());
                        tc.setExplanation(btc.getExplanation());
                        tc.setDisplayOrder(btc.getDisplayOrder());
                        copied.add(testCaseRepository.save(tc));
                    }
                    return copied;
                }
            }
        }
        return Collections.emptyList();
    }

    // ------------------------------------------------------------------ delivery

    /**
     * The student-facing paper. Deliberately builds its own maps instead of returning
     * entities: {@code isCorrect} must never reach the device before submission, or the
     * answer key can simply be read out of the network response.
     */
    public List<Map<String, Object>> studentPaper(AssessmentType type, Long assessmentId) {
        return studentPaper(type, assessmentId, null);
    }

    public List<Map<String, Object>> studentPaper(AssessmentType type, Long assessmentId, Long userId) {
        Map<Long, AssessmentResponse> byQuestion = (userId != null)
                ? responseRepository.findByAssessmentTypeAndAssessmentIdAndUserId(type, assessmentId, userId).stream()
                        .collect(Collectors.toMap(AssessmentResponse::getQuestionId, r -> r, (a, b) -> a))
                : Collections.emptyMap();

        return questions(type, assessmentId).stream().map(q -> {
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("id", q.getId());
            item.put("questionText", q.getQuestionText());
            item.put("questionType", q.getQuestionType().name());
            item.put("marks", q.getMarks());
            item.put("displayOrder", q.getDisplayOrder());
            item.put("explanation", q.getExplanation());
            item.put("codingDifficulty", q.getCodingDifficulty());
            item.put("codingConstraints", q.getCodingConstraints());
            item.put("codingInputFormat", q.getCodingInputFormat());
            item.put("codingOutputFormat", q.getCodingOutputFormat());
            item.put("codingStarterJava", q.getCodingStarterJava());
            item.put("codingStarterPython", q.getCodingStarterPython());
            item.put("options", q.getOptions().stream().map(o -> {
                Map<String, Object> opt = new LinkedHashMap<>();
                opt.put("id", o.getId());
                opt.put("optionText", o.getOptionText());
                return opt;
            }).collect(Collectors.toList()));

            AssessmentResponse resp = byQuestion.get(q.getId());
            if (resp != null) {
                item.put("answered", true);
                item.put("answerText", resp.getAnswerText());
                item.put("selectedOptionIds", resp.getSelectedOptionIds());
                item.put("marksAwarded", resp.getMarksAwarded());
                item.put("isCorrect", resp.getIsCorrect());
                item.put("testCasesPassed", resp.getTestCasesPassed());
                item.put("totalTestCases", resp.getTotalTestCases());
            } else {
                item.put("answered", false);
            }

            if (q.getQuestionType() == AssessmentQuestion.QuestionType.CODING) {
                List<CodingTestCase> samples = testCaseRepository.findByQuestionIdAndIsSampleTrueOrderByDisplayOrderAscIdAsc(q.getId());
                if (samples.isEmpty()) {
                    List<CodingTestCase> allTcs = testCaseRepository.findByQuestionIdOrderByDisplayOrderAscIdAsc(q.getId());
                    if (allTcs.isEmpty()) {
                        allTcs = copyTestCasesFromBankIfAvailable(q);
                    }
                    samples = allTcs.stream().limit(2).collect(Collectors.toList());
                }
                item.put("sampleTestCases", samples.stream().map(tc -> {
                    Map<String, Object> t = new LinkedHashMap<>();
                    t.put("id", tc.getId());
                    t.put("input", tc.getInput());
                    t.put("expectedOutput", tc.getExpectedOutput());
                    t.put("explanation", tc.getExplanation());
                    return t;
                }).collect(Collectors.toList()));
            }

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
        item.put("title", q.getCodingTitle() != null ? q.getCodingTitle() : q.getQuestionText());
        item.put("codingTitle", q.getCodingTitle());
        item.put("questionText", q.getQuestionText());
        item.put("questionType", q.getQuestionType().name());
        item.put("explanation", q.getExplanation());
        item.put("marks", q.getMarks());
        item.put("displayOrder", q.getDisplayOrder());
        item.put("answerText", q.getAnswerText());
        item.put("codingDifficulty", q.getCodingDifficulty());
        item.put("codingConstraints", q.getCodingConstraints());
        item.put("codingInputFormat", q.getCodingInputFormat());
        item.put("codingOutputFormat", q.getCodingOutputFormat());
        item.put("codingStarterJava", q.getCodingStarterJava());
        item.put("codingStarterPython", q.getCodingStarterPython());
        item.put("options", q.getOptions().stream().map(o -> {
            Map<String, Object> opt = new LinkedHashMap<>();
            opt.put("id", o.getId());
            opt.put("optionText", o.getOptionText());
            opt.put("isCorrect", Boolean.TRUE.equals(o.getIsCorrect()));
            opt.put("displayOrder", o.getDisplayOrder());
            return opt;
        }).collect(Collectors.toList()));

        if (q.getQuestionType() == AssessmentQuestion.QuestionType.CODING) {
            List<CodingTestCase> tcs = testCaseRepository.findByQuestionIdOrderByDisplayOrderAscIdAsc(q.getId());
            item.put("testCases", tcs.stream().map(tc -> {
                Map<String, Object> t = new LinkedHashMap<>();
                t.put("id", tc.getId());
                t.put("input", tc.getInput());
                t.put("expectedOutput", tc.getExpectedOutput());
                t.put("isSample", tc.getIsSample());
                t.put("explanation", tc.getExplanation());
                t.put("displayOrder", tc.getDisplayOrder());
                return t;
            }).collect(Collectors.toList()));
        }

        return item;
    }


    /**
     * COMPANY_KIT has its own branch rather than falling into the EXAM check: a
     * {@link com.institute.lms.entity.CompanyQuestionKit} id is not an {@code Exam}
     * id, so checking {@code examSubmissionRepository} here could match (or miss)
     * an unrelated exam submission purely by primary-key coincidence.
     */
    public boolean hasSubmitted(AssessmentType type, Long assessmentId, Long userId) {
        if (type == AssessmentType.ASSIGNMENT) {
            return assignmentSubmissionRepository.findByUserIdAndAssignmentId(userId, assessmentId).isPresent();
        } else if (type == AssessmentType.EXAM) {
            return examSubmissionRepository.findByUserIdAndExamId(userId, assessmentId).isPresent();
        }
        return !responseRepository.findByAssessmentTypeAndAssessmentIdAndUserId(type, assessmentId, userId).isEmpty();
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
        Map<Long, String> answerTextByQuestion = new HashMap<>();
        if (answers != null) {
            for (AnswerForm answer : answers) {
                if (answer.questionId == null) continue;
                selectionsByQuestion.put(answer.questionId,
                        answer.selectedOptionIds == null ? Collections.emptyList() : answer.selectedOptionIds);
                answerTextByQuestion.put(answer.questionId, answer.answerText);
            }
        }

        Map<Long, AssessmentResponse> existingByQuestion = responseRepository
                .findByAssessmentTypeAndAssessmentIdAndUserId(type, assessmentId, userId).stream()
                .collect(Collectors.toMap(AssessmentResponse::getQuestionId, r -> r, (a, b) -> a));

        // A re-attempt overwrites previous answers
        responseRepository.deleteByAssessmentTypeAndAssessmentIdAndUserId(type, assessmentId, userId);

        int totalMarks = 0;
        int scored = 0;
        int correctCount = 0;
        List<Map<String, Object>> perQuestion = new ArrayList<>();

        for (AssessmentQuestion question : paper) {
            int questionMarks = question.getMarks() == null ? 1 : question.getMarks();
            totalMarks += questionMarks;

            AssessmentQuestion.QuestionType questionType = question.getQuestionType();
            String typedAnswer = answerTextByQuestion.get(question.getId());
            List<Long> selected;
            Boolean correct;
            int awarded;

            if (questionType == AssessmentQuestion.QuestionType.FILL_IN_BLANK) {
                selected = Collections.emptyList();
                String expected = question.getAnswerText();
                boolean match = expected != null && !expected.isBlank()
                        && typedAnswer != null && expected.trim().equalsIgnoreCase(typedAnswer.trim());
                correct = match;
                awarded = match ? questionMarks : 0;
            } else if (questionType == AssessmentQuestion.QuestionType.CODING) {
                selected = Collections.emptyList();
                AssessmentResponse existingCoding = existingByQuestion.get(question.getId());
                if (existingCoding != null) {
                    correct = existingCoding.getIsCorrect();
                    awarded = existingCoding.getMarksAwarded() != null ? existingCoding.getMarksAwarded() : 0;
                    if (typedAnswer == null || typedAnswer.isBlank()) {
                        typedAnswer = existingCoding.getAnswerText();
                    }
                } else {
                    correct = false;
                    awarded = 0;
                }
            } else {
                Set<Long> correctIds = question.getOptions().stream()
                        .filter(o -> Boolean.TRUE.equals(o.getIsCorrect()))
                        .map(AssessmentQuestionOption::getId)
                        .collect(Collectors.toCollection(LinkedHashSet::new));

                List<Long> selectedRaw = selectionsByQuestion.getOrDefault(question.getId(), Collections.emptyList());
                Set<Long> validOptionIds = question.getOptions().stream()
                        .map(AssessmentQuestionOption::getId).collect(Collectors.toSet());
                selected = selectedRaw.stream()
                        .filter(Objects::nonNull)
                        .filter(validOptionIds::contains)
                        .distinct()
                        .collect(Collectors.toList());

                // Exact-set match: every correct option picked, nothing extra.
                boolean match = !correctIds.isEmpty() && correctIds.equals(new HashSet<>(selected));
                correct = match;
                awarded = match ? questionMarks : 0;
            }

            scored += awarded;
            if (Boolean.TRUE.equals(correct)) correctCount++;

            AssessmentResponse response = new AssessmentResponse();
            response.setAssessmentType(type);
            response.setAssessmentId(assessmentId);
            response.setUserId(userId);
            response.setQuestionId(question.getId());
            response.setSelectedOptionIds(new ArrayList<>(selected));
            response.setAnswerText(typedAnswer);
            response.setIsCorrect(correct);
            response.setMarksAwarded(awarded);

            AssessmentResponse existing = existingByQuestion.get(question.getId());
            if (existing != null) {
                response.setLanguage(existing.getLanguage());
                response.setTestCasesPassed(existing.getTestCasesPassed());
                response.setTotalTestCases(existing.getTotalTestCases());
                response.setCodeOutput(existing.getCodeOutput());
            }

            responseRepository.save(response);

            Map<String, Object> review = withKey(question);
            review.put("selectedOptionIds", selected);
            review.put("answerText", typedAnswer);
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
        if (type == AssessmentType.COMPANY_KIT) {
            // Company kits are metadata-only tiles, not real Assignment/Exam rows - there is
            // no submission table to write into, and the id could otherwise collide with an
            // unrelated Assignment/Exam id purely by primary-key coincidence.
            return null;
        }

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
            // withKey() seeded "answerText" with the reference answer - preserve it under its
            // own key before overwriting with what the student actually typed, or a wrong
            // FILL_IN_BLANK answer would have no correct answer left to show in the review.
            item.put("correctAnswerText", question.getAnswerText());
            item.put("answerText", response != null ? response.getAnswerText() : null);
            item.put("isCorrect", response == null ? Boolean.FALSE : response.getIsCorrect());
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
                answer.put("answerText", response != null ? response.getAnswerText() : null);
                answer.put("correctAnswerText", question.getAnswerText());
                answer.put("isCorrect", response == null ? Boolean.FALSE : response.getIsCorrect());
                answer.put("marksAwarded",
                        response == null || response.getMarksAwarded() == null ? 0 : response.getMarksAwarded());
                answer.put("attempted", !selected.isEmpty()
                        || (response != null && response.getAnswerText() != null && !response.getAnswerText().isBlank()));
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
        public String title;
        public String codingTitle;
        public String questionText;
        public String explanation;
        public AssessmentQuestion.QuestionType questionType;
        public Integer marks;
        public Integer displayOrder;
        public List<OptionForm> options;
        /** Reference answer for FILL_IN_BLANK; optional non-graded notes for CODING. */
        public String answerText;
        public String codingStarterJava;
        public String codingStarterPython;
        public String codingConstraints;
        public String codingInputFormat;
        public String codingOutputFormat;
        public String codingDifficulty;
        public List<TestCaseForm> testCases;
    }

    public static class OptionForm {
        public String optionText;
        public Boolean isCorrect;
    }

    public static class TestCaseForm {
        public String input;
        public String expectedOutput;
        public Boolean isSample;
        public String explanation;
    }


    /** One student answer inside an attempt. */
    public static class AnswerForm {
        public Long questionId;
        public List<Long> selectedOptionIds;
        /** Typed answer for FILL_IN_BLANK/CODING questions. */
        public String answerText;
    }
}
