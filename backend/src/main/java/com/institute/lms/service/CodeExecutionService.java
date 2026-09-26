package com.institute.lms.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;
import java.util.concurrent.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@Service
public class CodeExecutionService {

    private static final Logger log = LoggerFactory.getLogger(CodeExecutionService.class);
    private static final long DEFAULT_TIMEOUT_SECONDS = 5;

    public enum Status {
        SUCCESS,
        WRONG_ANSWER,
        COMPILATION_ERROR,
        RUNTIME_ERROR,
        TIME_LIMIT_EXCEEDED,
        SYSTEM_ERROR
    }

    public static class TestCaseRun {
        public int testCaseIndex;
        public String input;
        public String expectedOutput;
        public String actualOutput;
        public boolean passed;
        public Status status;
        public String error;
        public long executionTimeMs;
        public boolean isSample;
    }

    public static class ExecutionSummary {
        public Status overallStatus;
        public int totalTestCases;
        public int passedTestCases;
        public long totalExecutionTimeMs;
        public String compilationError;
        public List<TestCaseRun> results = new ArrayList<>();
    }

    private static volatile Boolean cachedJavacAvailable = null;
    private static volatile String cachedPythonCmd = null;

    /**
     * Executes code against a list of test cases.
     * Supports both JDK (javac) and lightweight JRE (java single-file source runner).
     */
    public ExecutionSummary executeTestCases(String language, String code, List<TestCaseRun> testCases) {
        ExecutionSummary summary = new ExecutionSummary();
        summary.totalTestCases = testCases == null ? 0 : testCases.size();
        if (code == null || code.isBlank()) {
            summary.overallStatus = Status.COMPILATION_ERROR;
            summary.compilationError = "No code provided.";
            return summary;
        }

        String lang = language == null ? "python" : language.trim().toLowerCase();
        Path tempDir = null;

        try {
            tempDir = Files.createTempDirectory("lms_code_exec_");

            if ("java".equals(lang)) {
                return executeJavaBatch(tempDir, code, testCases, summary);
            } else if ("python".equals(lang) || "py".equals(lang)) {
                return executePythonBatch(tempDir, code, testCases, summary);
            } else {
                summary.overallStatus = Status.SYSTEM_ERROR;
                summary.compilationError = "Unsupported language: " + language + ". Supported: java, python";
                return summary;
            }
        } catch (Exception e) {
            log.error("Failed to execute code batch", e);
            summary.overallStatus = Status.SYSTEM_ERROR;
            summary.compilationError = "Execution engine error: " + e.getMessage();
            return summary;
        } finally {
            if (tempDir != null) {
                deleteDirectoryRecursively(tempDir.toFile());
            }
        }
    }

    /**
     * Runs custom input without predefined test cases.
     */
    public TestCaseRun executeCustomInput(String language, String code, String customInput) {
        TestCaseRun item = new TestCaseRun();
        item.testCaseIndex = 1;
        item.input = customInput == null ? "" : customInput;
        item.expectedOutput = "";
        item.isSample = true;

        ExecutionSummary summary = executeTestCases(language, code, Collections.singletonList(item));
        if (summary.compilationError != null && !summary.compilationError.isBlank()) {
            item.status = summary.overallStatus != null ? summary.overallStatus : Status.COMPILATION_ERROR;
            item.error = summary.compilationError;
            item.passed = false;
            return item;
        }

        if (!summary.results.isEmpty()) {
            return summary.results.get(0);
        }

        item.status = Status.SYSTEM_ERROR;
        item.error = "No output produced";
        return item;
    }

    // ---------------------------------------------------------------- Java Execution

    private ExecutionSummary executeJavaBatch(Path tempDir, String code, List<TestCaseRun> testCases, ExecutionSummary summary) throws Exception {
        // Detect public class name or default to Solution
        String className = "Solution";
        Matcher matcher = Pattern.compile("public\\s+class\\s+([A-Za-z0-9_]+)").matcher(code);
        if (matcher.find()) {
            className = matcher.group(1);
        } else if (!code.contains("class " + className)) {
            Matcher anyClass = Pattern.compile("class\\s+([A-Za-z0-9_]+)").matcher(code);
            if (anyClass.find()) {
                className = anyClass.group(1);
            }
        }

        Path javaFile = tempDir.resolve(className + ".java");
        Files.writeString(javaFile, code, StandardCharsets.UTF_8);

        // Check if javac is installed and can compile
        boolean javacAvailable = isJavacAvailable();
        boolean compiledWithJavac = false;

        if (javacAvailable) {
            try {
                ProcessBuilder compilePb = new ProcessBuilder("javac", "-encoding", "UTF-8", javaFile.getFileName().toString());
                compilePb.directory(tempDir.toFile());
                compilePb.redirectErrorStream(true);

                Process compileProcess = compilePb.start();
                boolean compileFinished = compileProcess.waitFor(10, TimeUnit.SECONDS);

                if (!compileFinished) {
                    compileProcess.destroyForcibly();
                    summary.overallStatus = Status.COMPILATION_ERROR;
                    summary.compilationError = "Compilation timed out after 10 seconds.";
                    return summary;
                }

                String compileOutput = readStream(compileProcess.getInputStream());
                if (compileProcess.exitValue() != 0) {
                    summary.overallStatus = Status.COMPILATION_ERROR;
                    summary.compilationError = compileOutput;
                    return summary;
                }
                compiledWithJavac = true;
            } catch (IOException e) {
                log.warn("javac execution failed: {}. Falling back to single-file source runner (java {}.java)", e.getMessage(), className);
                compiledWithJavac = false;
            }
        }

        // When javac is unavailable (JRE environment), Java 11/17/21 can execute single-file source directly: `java Solution.java`
        String targetArg = compiledWithJavac ? className : javaFile.getFileName().toString();

        List<TestCaseRun> runs = (testCases == null || testCases.isEmpty())
                ? Collections.singletonList(createDummyTestCase())
                : testCases;

        int passed = 0;
        long totalTime = 0;
        boolean allPassed = true;

        for (int i = 0; i < runs.size(); i++) {
            TestCaseRun tc = runs.get(i);
            tc.testCaseIndex = i + 1;
            runSingleJava(tempDir, targetArg, tc);
            summary.results.add(tc);
            totalTime += tc.executionTimeMs;

            // If running without javac, detect compilation failure from java launcher
            if (!compiledWithJavac && tc.error != null && (tc.error.contains("error:") || tc.error.contains("compilation failed"))) {
                summary.overallStatus = Status.COMPILATION_ERROR;
                summary.compilationError = tc.error;
                return summary;
            }

            if (tc.passed) {
                passed++;
            } else {
                allPassed = false;
            }
        }

        summary.passedTestCases = passed;
        summary.totalExecutionTimeMs = totalTime;
        summary.overallStatus = allPassed ? Status.SUCCESS : Status.WRONG_ANSWER;
        return summary;
    }

    private void runSingleJava(Path tempDir, String targetArg, TestCaseRun tc) {
        ProcessBuilder runPb = new ProcessBuilder("java", "-Xmx256m", "-Xms32m", "-Dfile.encoding=UTF-8", targetArg);
        runPb.directory(tempDir.toFile());

        executeProcess(runPb, tc.input, tc);
        evaluateTestCase(tc);
    }

    private boolean isJavacAvailable() {
        if (cachedJavacAvailable != null) return cachedJavacAvailable;
        try {
            Process p = new ProcessBuilder("javac", "-version").start();
            boolean finished = p.waitFor(2, TimeUnit.SECONDS);
            cachedJavacAvailable = finished && p.exitValue() == 0;
        } catch (Exception e) {
            cachedJavacAvailable = false;
        }
        log.info("javac compiler available: {}", cachedJavacAvailable);
        return cachedJavacAvailable;
    }

    // ---------------------------------------------------------------- Python Execution

    private ExecutionSummary executePythonBatch(Path tempDir, String code, List<TestCaseRun> testCases, ExecutionSummary summary) throws Exception {
        Path pyFile = tempDir.resolve("solution.py");
        Files.writeString(pyFile, code, StandardCharsets.UTF_8);

        String pythonCmd = resolvePythonCommand();
        if (pythonCmd == null) {
            summary.overallStatus = Status.SYSTEM_ERROR;
            summary.compilationError = "Python is not installed on this server. Please install python3 (e.g. 'apk add python3' or 'apt-get install -y python3').";
            return summary;
        }

        List<TestCaseRun> runs = (testCases == null || testCases.isEmpty())
                ? Collections.singletonList(createDummyTestCase())
                : testCases;

        int passed = 0;
        long totalTime = 0;
        boolean allPassed = true;

        for (int i = 0; i < runs.size(); i++) {
            TestCaseRun tc = runs.get(i);
            tc.testCaseIndex = i + 1;
            runSinglePython(tempDir, pythonCmd, pyFile.getFileName().toString(), tc);
            summary.results.add(tc);
            totalTime += tc.executionTimeMs;
            if (tc.passed) {
                passed++;
            } else {
                allPassed = false;
            }
        }

        summary.passedTestCases = passed;
        summary.totalExecutionTimeMs = totalTime;
        summary.overallStatus = allPassed ? Status.SUCCESS : Status.WRONG_ANSWER;
        return summary;
    }

    private void runSinglePython(Path tempDir, String pythonCmd, String fileName, TestCaseRun tc) {
        ProcessBuilder runPb = new ProcessBuilder(pythonCmd, "-u", fileName);
        runPb.directory(tempDir.toFile());

        executeProcess(runPb, tc.input, tc);
        evaluateTestCase(tc);
    }

    private String resolvePythonCommand() {
        if (cachedPythonCmd != null) return cachedPythonCmd;

        String[] candidates = {
                "python3",
                "/usr/bin/python3",
                "/usr/local/bin/python3",
                "python",
                "/usr/bin/python",
                "py"
        };

        for (String cmd : candidates) {
            try {
                Process p = new ProcessBuilder(cmd, "--version").start();
                boolean finished = p.waitFor(2, TimeUnit.SECONDS);
                if (finished && p.exitValue() == 0) {
                    cachedPythonCmd = cmd;
                    log.info("Detected working Python binary: {}", cmd);
                    return cmd;
                }
            } catch (Exception ignored) {
            }
        }

        log.warn("No working Python binary found among candidates: {}", Arrays.toString(candidates));
        return null;
    }

    // ---------------------------------------------------------------- Shared Process Runner

    private void executeProcess(ProcessBuilder pb, String input, TestCaseRun tc) {
        long start = System.currentTimeMillis();
        Process process = null;
        try {
            process = pb.start();
            final Process p = process;

            // Prepare stdin data: normalize line endings and ensure trailing newline so Scanner/readline does not hit premature EOF
            String normalizedInput = "";
            if (input != null && !input.isBlank()) {
                normalizedInput = input.replace("\r\n", "\n").replace("\r", "\n");
                if (!normalizedInput.endsWith("\n")) {
                    normalizedInput = normalizedInput + "\n";
                }
            }
            final String stdinData = normalizedInput;

            // Asynchronously feed stdin to child process so pipe remains open while JVM/process initializes
            CompletableFuture<Void> stdinFuture = CompletableFuture.runAsync(() -> {
                try (OutputStream os = p.getOutputStream()) {
                    if (!stdinData.isEmpty()) {
                        os.write(stdinData.getBytes(StandardCharsets.UTF_8));
                        os.flush();
                    }
                } catch (IOException ignored) {
                    // Child process may terminate early or close stdin, which is normal
                }
            });

            // Capture streams in parallel
            Future<String> stdoutFuture = CompletableFuture.supplyAsync(() -> readStream(p.getInputStream()));
            Future<String> stderrFuture = CompletableFuture.supplyAsync(() -> readStream(p.getErrorStream()));

            boolean finished = process.waitFor(DEFAULT_TIMEOUT_SECONDS, TimeUnit.SECONDS);
            long duration = System.currentTimeMillis() - start;
            tc.executionTimeMs = duration;

            if (!finished) {
                process.destroyForcibly();
                tc.status = Status.TIME_LIMIT_EXCEEDED;
                tc.error = "Time Limit Exceeded (> " + DEFAULT_TIMEOUT_SECONDS + " seconds)";
                tc.actualOutput = "";
                return;
            }

            String stdout = stdoutFuture.get(1, TimeUnit.SECONDS);
            String stderr = stderrFuture.get(1, TimeUnit.SECONDS);

            if (process.exitValue() != 0) {
                tc.status = Status.RUNTIME_ERROR;
                String err = stderr != null && !stderr.isBlank() ? stderr : "Process exited with code " + process.exitValue();

                // Enhance user-friendly hint if NoSuchElementException occurs due to empty stdin
                if (err.contains("NoSuchElementException") && stdinData.isEmpty()) {
                    err = err + "\n\n[LMS Notice] The program attempted to read from standard input (stdin/Scanner), but standard input was empty.\n💡 Solution: Switch to the 'Custom Input' tab in the console panel below, enter the input data your program requires, and click 'Run Code'.";
                } else if (err.contains("EOFError") && stdinData.isEmpty()) {
                    err = err + "\n\n[LMS Notice] The program attempted to read from standard input (sys.stdin/input()), but standard input was empty.\n💡 Solution: Switch to the 'Custom Input' tab in the console panel below, enter the input data your program requires, and click 'Run Code'.";
                }
                tc.error = err;
                tc.actualOutput = stdout != null ? stdout : "";
            } else {
                tc.status = Status.SUCCESS;
                tc.actualOutput = stdout != null ? stdout : "";
                tc.error = stderr != null && !stderr.isBlank() ? stderr : null;
            }
        } catch (IOException e) {
            tc.status = Status.SYSTEM_ERROR;
            tc.error = "Executable not found or cannot run: " + e.getMessage();
            tc.actualOutput = "";
            tc.executionTimeMs = System.currentTimeMillis() - start;
        } catch (Exception e) {
            tc.status = Status.SYSTEM_ERROR;
            tc.error = "Process execution error: " + e.getMessage();
            tc.actualOutput = "";
            tc.executionTimeMs = System.currentTimeMillis() - start;
        } finally {
            if (process != null && process.isAlive()) {
                process.destroyForcibly();
            }
        }
    }

    private void evaluateTestCase(TestCaseRun tc) {
        if (tc.status != Status.SUCCESS) {
            tc.passed = false;
            return;
        }

        if (tc.expectedOutput == null || tc.expectedOutput.isBlank()) {
            tc.passed = true;
            return;
        }

        boolean matched = normalize(tc.expectedOutput).equals(normalize(tc.actualOutput));
        tc.passed = matched;
        if (!matched && tc.status == Status.SUCCESS) {
            tc.status = Status.WRONG_ANSWER;
        }
    }

    private String normalize(String s) {
        if (s == null) return "";
        return s.replace("\r\n", "\n")
                .trim()
                .replaceAll("[ \t]+$", "");
    }

    private static TestCaseRun createDummyTestCase() {
        TestCaseRun dummy = new TestCaseRun();
        dummy.testCaseIndex = 1;
        dummy.input = "";
        dummy.expectedOutput = "";
        dummy.isSample = true;
        return dummy;
    }

    private static String readStream(InputStream is) {
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(is, StandardCharsets.UTF_8))) {
            StringBuilder sb = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) {
                if (sb.length() > 0) sb.append("\n");
                sb.append(line);
                if (sb.length() > 50000) {
                    sb.append("\n...[output truncated]");
                    break;
                }
            }
            return sb.toString();
        } catch (Exception e) {
            return "";
        }
    }

    private static void deleteDirectoryRecursively(File file) {
        if (file == null || !file.exists()) return;
        if (file.isDirectory()) {
            File[] files = file.listFiles();
            if (files != null) {
                for (File child : files) {
                    deleteDirectoryRecursively(child);
                }
            }
        }
        file.delete();
    }
}
