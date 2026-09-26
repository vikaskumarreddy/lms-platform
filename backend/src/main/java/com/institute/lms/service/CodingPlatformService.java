package com.institute.lms.service;

import com.institute.lms.entity.*;
import com.institute.lms.repository.*;
import com.institute.lms.util.OrganizationContext;
import com.institute.lms.util.UserContext;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;

@Service
public class CodingPlatformService {

    private static final Logger log = LoggerFactory.getLogger(CodingPlatformService.class);

    private final AssessmentQuestionRepository questionRepository;
    private final CodingTestCaseRepository testCaseRepository;
    private final AssessmentResponseRepository responseRepository;
    private final AssignmentSubmissionRepository assignmentSubmissionRepository;
    private final ExamSubmissionRepository examSubmissionRepository;
    private final OrganizationRepository organizationRepository;
    private final UserRepository userRepository;
    private final CodeExecutionService executionService;
    private final UserContext userContext;

    public CodingPlatformService(AssessmentQuestionRepository questionRepository,
                                 CodingTestCaseRepository testCaseRepository,
                                 AssessmentResponseRepository responseRepository,
                                 AssignmentSubmissionRepository assignmentSubmissionRepository,
                                 ExamSubmissionRepository examSubmissionRepository,
                                 OrganizationRepository organizationRepository,
                                 UserRepository userRepository,
                                 CodeExecutionService executionService,
                                 UserContext userContext) {
        this.questionRepository = questionRepository;
        this.testCaseRepository = testCaseRepository;
        this.responseRepository = responseRepository;
        this.assignmentSubmissionRepository = assignmentSubmissionRepository;
        this.examSubmissionRepository = examSubmissionRepository;
        this.organizationRepository = organizationRepository;
        this.userRepository = userRepository;
        this.executionService = executionService;
        this.userContext = userContext;
    }

    // ------------------------------------------------------------------ Boilerplate defaults

    public static final String DEFAULT_JAVA_STARTER =
            "import java.util.*;\n\n" +
            "public class Solution {\n" +
            "    public static void main(String[] args) {\n" +
            "        Scanner sc = new Scanner(System.in);\n" +
            "        // Write your solution here\n" +
            "        \n" +
            "    }\n" +
            "}";

    public static final String DEFAULT_PYTHON_STARTER =
            "import sys\n\n" +
            "def main():\n" +
            "    # Read from standard input\n" +
            "    input_data = sys.stdin.read().split()\n" +
            "    # Write your solution here\n" +
            "    pass\n\n" +
            "if __name__ == '__main__':\n" +
            "    main()\n";

    // ------------------------------------------------------------------ DTOs

    public static class RunRequest {
        public Long questionId;
        public String language; // "java" | "python"
        public String code;
        public String sourceCode;
        public String customInput;
        public List<TestCaseItem> customTestCases;

        public String getEffectiveCode() {
            if (sourceCode != null && !sourceCode.isBlank()) return sourceCode;
            return code;
        }
    }

    public static class SubmitRequest {
        public Long questionId;
        public String assessmentType; // "ASSIGNMENT" | "EXAM" | "PRACTICE"
        public Long assessmentId;
        public Long userId;
        public String language; // "java" | "python"
        public String code;
        public String sourceCode;
        public List<TestCaseItem> customTestCases;

        public String getEffectiveCode() {
            if (sourceCode != null && !sourceCode.isBlank()) return sourceCode;
            return code;
        }
    }

    public static class TestCaseItem {
        public Long id;
        public String input;
        public String expectedOutput;
        public boolean isSample;
        public String explanation;
        public int displayOrder;
    }

    public static class QuestionDetailDTO {
        public Long id;
        public String title;
        public String questionText;
        public String problemStatement;
        public String explanation;
        public Integer marks;
        public String difficulty;
        public String constraints;
        public String inputFormat;
        public String outputFormat;
        public String starterJava;
        public String starterPython;
        public List<TestCaseItem> sampleTestCases = new ArrayList<>();
        public int totalTestCases;
        public int totalTestCasesCount;
        public String orgName;
        public String orgLogoUrl;
        public Map<String, Object> orgBranding = new HashMap<>();
    }

    // ------------------------------------------------------------------ Read Question Details

    @Transactional(readOnly = true)
    public QuestionDetailDTO getQuestionDetails(Long questionId, Long orgId) {
        AssessmentQuestion q = questionRepository.findById(questionId)
                .orElseThrow(() -> new IllegalArgumentException("Question not found: " + questionId));

        QuestionDetailDTO dto = new QuestionDetailDTO();
        dto.id = q.getId();
        dto.title = (q.getCodingTitle() != null && !q.getCodingTitle().isBlank())
                ? q.getCodingTitle()
                : (q.getQuestionText() != null && q.getQuestionText().length() > 60
                ? q.getQuestionText().substring(0, 60) + "..." : q.getQuestionText());
        dto.questionText = q.getQuestionText();
        dto.problemStatement = q.getQuestionText();
        dto.explanation = q.getExplanation();
        dto.marks = q.getMarks() != null ? q.getMarks() : 10;
        dto.difficulty = q.getCodingDifficulty() != null ? q.getCodingDifficulty() : "MEDIUM";
        dto.constraints = q.getCodingConstraints() != null ? q.getCodingConstraints() : "Time Limit: 5.0s\nMemory Limit: 256MB\n1 <= N <= 10^5";
        dto.inputFormat = q.getCodingInputFormat() != null ? q.getCodingInputFormat() : "First line contains the input parameters.";
        dto.outputFormat = q.getCodingOutputFormat() != null ? q.getCodingOutputFormat() : "Print the result to standard output.";

        dto.starterJava = q.getCodingStarterJava() != null && !q.getCodingStarterJava().isBlank()
                ? q.getCodingStarterJava() : DEFAULT_JAVA_STARTER;
        dto.starterPython = q.getCodingStarterPython() != null && !q.getCodingStarterPython().isBlank()
                ? q.getCodingStarterPython() : DEFAULT_PYTHON_STARTER;

        List<CodingTestCase> allTcs = testCaseRepository.findByQuestionIdOrderByDisplayOrderAscIdAsc(questionId);
        dto.totalTestCases = allTcs.size();
        dto.totalTestCasesCount = allTcs.size();

        for (CodingTestCase tc : allTcs) {
            if (Boolean.TRUE.equals(tc.getIsSample())) {
                TestCaseItem item = new TestCaseItem();
                item.id = tc.getId();
                item.input = tc.getInput();
                item.expectedOutput = tc.getExpectedOutput();
                item.isSample = true;
                item.explanation = tc.getExplanation();
                item.displayOrder = tc.getDisplayOrder() != null ? tc.getDisplayOrder() : 0;
                dto.sampleTestCases.add(item);
            }
        }

        // If no test cases are explicitly flagged as sample, treat up to first 2 as samples
        if (dto.sampleTestCases.isEmpty() && !allTcs.isEmpty()) {
            for (int i = 0; i < Math.min(2, allTcs.size()); i++) {
                CodingTestCase tc = allTcs.get(i);
                TestCaseItem item = new TestCaseItem();
                item.id = tc.getId();
                item.input = tc.getInput();
                item.expectedOutput = tc.getExpectedOutput();
                item.isSample = true;
                item.explanation = tc.getExplanation();
                item.displayOrder = tc.getDisplayOrder() != null ? tc.getDisplayOrder() : 0;
                dto.sampleTestCases.add(item);
            }
        }

        // Add Organisation Branding
        resolveOrgBranding(orgId, dto.orgBranding);
        dto.orgName = (String) dto.orgBranding.get("orgName");
        dto.orgLogoUrl = (String) dto.orgBranding.get("logoUrl");

        return dto;
    }

    private void resolveOrgBranding(Long orgId, Map<String, Object> branding) {
        Organization org = null;
        if (orgId != null) {
            org = organizationRepository.findById(orgId).orElse(null);
        }
        if (org == null) {
            User user = userContext.currentUser();
            if (user != null && user.getOrganizationId() != null) {
                org = organizationRepository.findById(user.getOrganizationId()).orElse(null);
            }
        }
        if (org != null) {
            branding.put("orgId", org.getId());
            branding.put("orgName", org.getName());
            branding.put("logoUrl", org.getLogoUrl());
        } else {
            branding.put("orgName", "LMS Code Academy");
            branding.put("logoUrl", null);
        }
    }

    // ------------------------------------------------------------------ Run Code

    public Map<String, Object> runCode(RunRequest req) {
        String effectiveCode = req.getEffectiveCode();
        if (effectiveCode == null || effectiveCode.isBlank()) {
            Map<String, Object> out = new LinkedHashMap<>();
            out.put("success", false);
            out.put("verdict", "COMPILATION_ERROR");
            out.put("overallStatus", "COMPILATION_ERROR");
            out.put("error", "Please write some code before running.");
            out.put("compilationError", "Please write some code before running.");
            out.put("results", Collections.emptyList());
            return out;
        }

        // Custom input mode
        if (req.customInput != null && !req.customInput.trim().isEmpty()) {
            CodeExecutionService.TestCaseRun run = executionService.executeCustomInput(req.language, effectiveCode, req.customInput);
            CodeExecutionService.ExecutionSummary summary = new CodeExecutionService.ExecutionSummary();
            summary.totalTestCases = 1;
            summary.passedTestCases = run.status == CodeExecutionService.Status.SUCCESS ? 1 : 0;
            summary.overallStatus = run.status;
            summary.totalExecutionTimeMs = run.executionTimeMs;
            summary.results.add(run);
            return formatRunResponse(summary);
        }

        List<CodeExecutionService.TestCaseRun> testCasesToRun = new ArrayList<>();

        if (req.questionId != null && req.questionId > 0) {
            List<CodingTestCase> samples = testCaseRepository.findByQuestionIdAndIsSampleTrueOrderByDisplayOrderAscIdAsc(req.questionId);
            if (samples.isEmpty()) {
                List<CodingTestCase> allTcs = testCaseRepository.findByQuestionIdOrderByDisplayOrderAscIdAsc(req.questionId);
                samples = allTcs.stream().limit(2).collect(Collectors.toList());
            }
            for (int i = 0; i < samples.size(); i++) {
                CodingTestCase tc = samples.get(i);
                CodeExecutionService.TestCaseRun item = new CodeExecutionService.TestCaseRun();
                item.testCaseIndex = i + 1;
                item.input = tc.getInput() != null ? tc.getInput() : "";
                item.expectedOutput = tc.getExpectedOutput() != null ? tc.getExpectedOutput() : "";
                item.isSample = true;
                testCasesToRun.add(item);
            }
        }

        // Fallback to customTestCases sent by client if testCasesToRun is empty
        if (testCasesToRun.isEmpty() && req.customTestCases != null && !req.customTestCases.isEmpty()) {
            for (int i = 0; i < req.customTestCases.size(); i++) {
                TestCaseItem ctc = req.customTestCases.get(i);
                CodeExecutionService.TestCaseRun item = new CodeExecutionService.TestCaseRun();
                item.testCaseIndex = i + 1;
                item.input = ctc.input != null ? ctc.input : "";
                item.expectedOutput = ctc.expectedOutput != null ? ctc.expectedOutput : "";
                item.isSample = true;
                testCasesToRun.add(item);
            }
        }

        CodeExecutionService.ExecutionSummary summary = executionService.executeTestCases(req.language, effectiveCode, testCasesToRun);
        return formatRunResponse(summary);
    }

    private Map<String, Object> formatRunResponse(CodeExecutionService.ExecutionSummary summary) {
        String verdict = summary.overallStatus != null ? summary.overallStatus.name() : "SUCCESS";
        boolean success = summary.overallStatus == CodeExecutionService.Status.SUCCESS;

        List<Map<String, Object>> results = new ArrayList<>();
        for (CodeExecutionService.TestCaseRun run : summary.results) {
            Map<String, Object> r = new LinkedHashMap<>();
            r.put("testCaseIndex", run.testCaseIndex);
            r.put("testCaseNumber", run.testCaseIndex);
            r.put("passed", run.passed);
            r.put("status", run.status != null ? run.status.name() : "UNKNOWN");
            r.put("input", run.input);
            r.put("expectedOutput", run.expectedOutput);
            r.put("actualOutput", run.actualOutput);
            r.put("error", run.error);
            r.put("errorOutput", run.error);
            r.put("executionTimeMs", run.executionTimeMs);
            r.put("isSample", run.isSample);
            results.add(r);
        }

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("success", success);
        out.put("verdict", verdict);
        out.put("overallStatus", verdict);
        out.put("totalTestCases", summary.totalTestCases);
        out.put("passedTestCases", summary.passedTestCases);
        out.put("totalExecutionTimeMs", summary.totalExecutionTimeMs);
        out.put("error", summary.compilationError);
        out.put("compilationError", summary.compilationError);
        out.put("results", results);
        return out;
    }

    // ------------------------------------------------------------------ Submit Solution & Auto-Grade

    @Transactional
    public Map<String, Object> submitSolution(SubmitRequest req) {
        String effectiveCode = req.getEffectiveCode();
        if (effectiveCode == null || effectiveCode.isBlank()) {
            Map<String, Object> out = new LinkedHashMap<>();
            out.put("success", false);
            out.put("verdict", "COMPILATION_ERROR");
            out.put("status", "COMPILATION_ERROR");
            out.put("testCasesPassed", 0);
            out.put("passedTestCases", 0);
            out.put("totalTestCases", 0);
            out.put("marksAwarded", 0);
            out.put("totalMarks", 10);
            out.put("scorePercentage", 0);
            out.put("message", "Please write code before submitting.");
            out.put("error", "No code provided.");
            out.put("results", Collections.emptyList());
            return out;
        }

        AssessmentQuestion question = null;
        if (req.questionId != null && req.questionId > 0) {
            question = questionRepository.findById(req.questionId).orElse(null);
        }

        List<CodingTestCase> allTestCases = Collections.emptyList();
        if (question != null) {
            allTestCases = testCaseRepository.findByQuestionIdOrderByDisplayOrderAscIdAsc(req.questionId);
        }

        List<CodeExecutionService.TestCaseRun> runnerItems = new ArrayList<>();

        if (!allTestCases.isEmpty()) {
            for (int i = 0; i < allTestCases.size(); i++) {
                CodingTestCase tc = allTestCases.get(i);
                CodeExecutionService.TestCaseRun item = new CodeExecutionService.TestCaseRun();
                item.testCaseIndex = i + 1;
                item.input = tc.getInput();
                item.expectedOutput = tc.getExpectedOutput();
                item.isSample = Boolean.TRUE.equals(tc.getIsSample());
                runnerItems.add(item);
            }
        } else if (req.customTestCases != null && !req.customTestCases.isEmpty()) {
            for (int i = 0; i < req.customTestCases.size(); i++) {
                TestCaseItem ctc = req.customTestCases.get(i);
                CodeExecutionService.TestCaseRun item = new CodeExecutionService.TestCaseRun();
                item.testCaseIndex = i + 1;
                item.input = ctc.input != null ? ctc.input : "";
                item.expectedOutput = ctc.expectedOutput != null ? ctc.expectedOutput : "";
                item.isSample = ctc.isSample;
                runnerItems.add(item);
            }
        }

        CodeExecutionService.ExecutionSummary summary = executionService.executeTestCases(req.language, effectiveCode, runnerItems);

        int total = runnerItems.size();
        int passed = summary.passedTestCases;
        boolean allPassed = total > 0 && passed == total;
        int maxMarks = question != null && question.getMarks() != null ? question.getMarks() : 10;
        int awarded = total == 0 ? maxMarks : (int) Math.round(((double) passed / total) * maxMarks);
        int scorePercentage = total > 0 ? (int) Math.round(((double) passed / total) * 100) : 0;

        Long effectiveUserId = req.userId;
        if (effectiveUserId == null) {
            User current = userContext.currentUser();
            if (current != null) effectiveUserId = current.getId();
        }

        if (effectiveUserId != null && question != null) {
            AssessmentType type = parseAssessmentType(req.assessmentType);

            // Save or update response
            AssessmentResponse response = null;
            if (type != null && req.assessmentId != null) {
                List<AssessmentResponse> existing = responseRepository.findByAssessmentTypeAndAssessmentIdAndUserId(type, req.assessmentId, effectiveUserId);
                for (AssessmentResponse r : existing) {
                    if (question.getId().equals(r.getQuestionId())) {
                        response = r;
                        break;
                    }
                }
            }

            if (response == null) {
                response = new AssessmentResponse();
                response.setQuestionId(question.getId());
                response.setUserId(effectiveUserId);
                response.setAssessmentType(type != null ? type : AssessmentType.ASSIGNMENT);
                response.setAssessmentId(req.assessmentId != null ? req.assessmentId : 0L);
            }

            response.setAnswerText(effectiveCode);
            response.setLanguage(req.language);
            response.setIsCorrect(allPassed);
            response.setMarksAwarded(awarded);
            response.setTestCasesPassed(passed);
            response.setTotalTestCases(total);
            response.setCodeOutput(summary.compilationError != null
                    ? summary.compilationError
                    : (passed + "/" + total + " test cases passed."));
            responseRepository.save(response);

            // Sync with Assignment or Exam submission if applicable
            syncAssessmentSubmission(type, req.assessmentId, effectiveUserId);
        }

        // Sanitize results: hide input and expected output for hidden test cases
        List<Map<String, Object>> sanitizedResults = new ArrayList<>();
        for (CodeExecutionService.TestCaseRun run : summary.results) {
            Map<String, Object> r = new LinkedHashMap<>();
            r.put("testCaseIndex", run.testCaseIndex);
            r.put("testCaseNumber", run.testCaseIndex);
            r.put("passed", run.passed);
            r.put("status", run.status != null ? run.status.name() : "UNKNOWN");
            r.put("isSample", run.isSample);
            r.put("executionTimeMs", run.executionTimeMs);

            if (run.isSample) {
                r.put("input", run.input);
                r.put("expectedOutput", run.expectedOutput);
                r.put("actualOutput", run.actualOutput);
            } else {
                r.put("input", "[Hidden Test Case]");
                r.put("expectedOutput", "[Hidden]");
                r.put("actualOutput", run.passed ? "[Passed]" : "[Failed Output]");
            }
            if (run.error != null) {
                r.put("error", run.error);
                r.put("errorOutput", run.error);
            }
            sanitizedResults.add(r);
        }

        String verdict;
        if (summary.compilationError != null && !summary.compilationError.isBlank()) {
            verdict = "COMPILATION_ERROR";
        } else if (allPassed) {
            verdict = "ACCEPTED";
        } else {
            verdict = "WRONG_ANSWER";
        }

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("success", allPassed);
        out.put("verdict", verdict);
        out.put("status", verdict);
        out.put("allPassed", allPassed);
        out.put("totalTestCases", total);
        out.put("testCasesPassed", passed);
        out.put("passedTestCases", passed);
        out.put("marksAwarded", awarded);
        out.put("totalMarks", maxMarks);
        out.put("scorePercentage", scorePercentage);
        out.put("message", summary.compilationError != null
                ? summary.compilationError
                : (passed + "/" + total + " test cases passed."));
        out.put("error", summary.compilationError);
        out.put("compilationError", summary.compilationError);
        out.put("totalExecutionTimeMs", summary.totalExecutionTimeMs);
        out.put("results", sanitizedResults);
        out.put("submittedAt", LocalDateTime.now());

        return out;
    }

    private void syncAssessmentSubmission(AssessmentType type, Long assessmentId, Long userId) {
        if (type == null || assessmentId == null || userId == null) return;

        List<AssessmentResponse> allResponses = responseRepository.findByAssessmentTypeAndAssessmentIdAndUserId(type, assessmentId, userId);
        int totalScore = allResponses.stream().mapToInt(r -> r.getMarksAwarded() != null ? r.getMarksAwarded() : 0).sum();

        if (type == AssessmentType.ASSIGNMENT) {
            assignmentSubmissionRepository.findByUserIdAndAssignmentId(userId, assessmentId).ifPresent(sub -> {
                sub.setMarksObtained(totalScore);
                sub.setIsGraded(true);
                assignmentSubmissionRepository.save(sub);
            });
        } else if (type == AssessmentType.EXAM) {
            examSubmissionRepository.findByUserIdAndExamId(userId, assessmentId).ifPresent(sub -> {
                sub.setMarksObtained(totalScore);
                sub.setIsGraded(true);
                examSubmissionRepository.save(sub);
            });
        }
    }

    private AssessmentType parseAssessmentType(String typeStr) {
        if (typeStr == null || typeStr.isBlank()) return null;
        try {
            return AssessmentType.from(typeStr);
        } catch (Exception e) {
            return null;
        }
    }

    // ------------------------------------------------------------------ Admin Bank / Management

    @Transactional
    public AssessmentQuestion saveCodingQuestion(Long questionId, Map<String, Object> payload) {
        AssessmentQuestion q;
        if (questionId != null && questionId > 0) {
            q = questionRepository.findById(questionId)
                    .orElseThrow(() -> new IllegalArgumentException("Question not found: " + questionId));
        } else {
            q = new AssessmentQuestion();
            q.setQuestionType(AssessmentQuestion.QuestionType.CODING);
            String typeStr = (String) payload.get("assessmentType");
            q.setAssessmentType(typeStr != null ? AssessmentType.from(typeStr) : AssessmentType.PRACTICE);
            q.setAssessmentId(payload.get("assessmentId") != null ? ((Number) payload.get("assessmentId")).longValue() : 0L);
        }

        if (payload.containsKey("title")) {
            q.setCodingTitle((String) payload.get("title"));
        } else if (payload.containsKey("codingTitle")) {
            q.setCodingTitle((String) payload.get("codingTitle"));
        }

        if (payload.containsKey("questionText")) {
            q.setQuestionText((String) payload.get("questionText"));
        } else if (q.getCodingTitle() != null && (q.getQuestionText() == null || q.getQuestionText().isBlank())) {
            q.setQuestionText(q.getCodingTitle());
        }

        if (payload.containsKey("explanation")) q.setExplanation((String) payload.get("explanation"));
        if (payload.containsKey("marks") && payload.get("marks") != null) {
            q.setMarks(((Number) payload.get("marks")).intValue());
        }

        // Support both difficulty and codingDifficulty
        if (payload.containsKey("difficulty") && payload.get("difficulty") != null) {
            q.setCodingDifficulty((String) payload.get("difficulty"));
        } else if (payload.containsKey("codingDifficulty") && payload.get("codingDifficulty") != null) {
            q.setCodingDifficulty((String) payload.get("codingDifficulty"));
        }

        // Support both constraints and codingConstraints
        if (payload.containsKey("constraints")) {
            q.setCodingConstraints((String) payload.get("constraints"));
        } else if (payload.containsKey("codingConstraints")) {
            q.setCodingConstraints((String) payload.get("codingConstraints"));
        }

        // Support both inputFormat and codingInputFormat
        if (payload.containsKey("inputFormat")) {
            q.setCodingInputFormat((String) payload.get("inputFormat"));
        } else if (payload.containsKey("codingInputFormat")) {
            q.setCodingInputFormat((String) payload.get("codingInputFormat"));
        }

        // Support both outputFormat and codingOutputFormat
        if (payload.containsKey("outputFormat")) {
            q.setCodingOutputFormat((String) payload.get("outputFormat"));
        } else if (payload.containsKey("codingOutputFormat")) {
            q.setCodingOutputFormat((String) payload.get("codingOutputFormat"));
        }

        // Support both starterJava and codingStarterJava
        if (payload.containsKey("starterJava")) {
            q.setCodingStarterJava((String) payload.get("starterJava"));
        } else if (payload.containsKey("codingStarterJava")) {
            q.setCodingStarterJava((String) payload.get("codingStarterJava"));
        }

        // Support both starterPython and codingStarterPython
        if (payload.containsKey("starterPython")) {
            q.setCodingStarterPython((String) payload.get("starterPython"));
        } else if (payload.containsKey("codingStarterPython")) {
            q.setCodingStarterPython((String) payload.get("codingStarterPython"));
        }

        // Ensure organization id is stamped
        Long currentOrgId = OrganizationContext.getCurrentOrgIdStatic();
        if (q.getOrganizationId() == null && currentOrgId != null) {
            q.setOrganizationId(currentOrgId);
        }

        AssessmentQuestion saved = questionRepository.save(q);

        // Update Test Cases
        if (payload.containsKey("testCases")) {
            List<Map<String, Object>> tcList = (List<Map<String, Object>>) payload.get("testCases");
            testCaseRepository.deleteByQuestionId(saved.getId());

            if (tcList != null) {
                int order = 0;
                Long targetOrgId = saved.getOrganizationId() != null ? saved.getOrganizationId() : currentOrgId;
                for (Map<String, Object> map : tcList) {
                    CodingTestCase tc = new CodingTestCase();
                    tc.setQuestion(saved);
                    tc.setOrganizationId(targetOrgId);
                    tc.setInput(map.get("input") != null ? (String) map.get("input") : "");
                    tc.setExpectedOutput(map.get("expectedOutput") != null ? (String) map.get("expectedOutput") : "");
                    tc.setIsSample(Boolean.TRUE.equals(map.get("isSample")));
                    tc.setExplanation((String) map.get("explanation"));
                    tc.setDisplayOrder(order++);
                    testCaseRepository.save(tc);
                }
            }
        }

        return saved;
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> getCodingBank() {
        // Query only Coding Bank questions (exclude questions that belong to a specific exam/assignment)
        List<AssessmentQuestion> list = questionRepository.findCodingBankQuestions(AssessmentQuestion.QuestionType.CODING);
        List<Map<String, Object>> results = new ArrayList<>();

        for (AssessmentQuestion q : list) {
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("id", q.getId());
            item.put("title", (q.getCodingTitle() != null && !q.getCodingTitle().isBlank())
                    ? q.getCodingTitle()
                    : (q.getQuestionText() != null && q.getQuestionText().length() > 50
                    ? q.getQuestionText().substring(0, 50) + "..." : q.getQuestionText()));
            item.put("questionText", q.getQuestionText());
            item.put("explanation", q.getExplanation());
            item.put("marks", q.getMarks() != null ? q.getMarks() : 10);
            item.put("difficulty", q.getCodingDifficulty() != null ? q.getCodingDifficulty() : "MEDIUM");
            item.put("constraints", q.getCodingConstraints());
            item.put("inputFormat", q.getCodingInputFormat());
            item.put("outputFormat", q.getCodingOutputFormat());
            item.put("starterJava", q.getCodingStarterJava());
            item.put("starterPython", q.getCodingStarterPython());
            item.put("assessmentType", q.getAssessmentType());
            item.put("assessmentId", q.getAssessmentId());

            List<CodingTestCase> tcs = testCaseRepository.findByQuestionIdOrderByDisplayOrderAscIdAsc(q.getId());
            item.put("totalTestCases", tcs.size());
            item.put("testCaseCount", tcs.size());
            item.put("sampleTestCases", tcs.stream().filter(t -> Boolean.TRUE.equals(t.getIsSample())).count());

            List<Map<String, Object>> tcDtoList = new ArrayList<>();
            for (CodingTestCase tc : tcs) {
                Map<String, Object> tcMap = new LinkedHashMap<>();
                tcMap.put("id", tc.getId());
                tcMap.put("input", tc.getInput());
                tcMap.put("expectedOutput", tc.getExpectedOutput());
                tcMap.put("isSample", Boolean.TRUE.equals(tc.getIsSample()));
                tcMap.put("explanation", tc.getExplanation());
                tcMap.put("displayOrder", tc.getDisplayOrder());
                tcDtoList.add(tcMap);
            }
            item.put("testCases", tcDtoList);

            results.add(item);
        }

        return results;
    }

    @Transactional
    public void deleteCodingQuestion(Long questionId) {
        if (questionId == null) return;
        testCaseRepository.deleteByQuestionId(questionId);
        questionRepository.deleteById(questionId);
    }
}
