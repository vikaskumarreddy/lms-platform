package com.institute.lms.controller;

import com.institute.lms.entity.InterviewSession;
import com.institute.lms.entity.InterviewSlot;
import com.institute.lms.entity.PlacementDrive;
import com.institute.lms.entity.User;
import com.institute.lms.repository.InterviewSessionRepository;
import com.institute.lms.repository.InterviewSlotRepository;
import com.institute.lms.repository.UserRepository;
import com.institute.lms.service.CodeExecutionService;
import com.institute.lms.service.HundredMsService;
import com.institute.lms.util.UserContext;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.*;

@RestController
@RequestMapping("/api/interviews")
public class InterviewRoomController {

    private final InterviewSessionRepository sessionRepository;
    private final InterviewSlotRepository slotRepository;
    private final UserRepository userRepository;
    private final HundredMsService hundredMsService;
    private final CodeExecutionService codeExecutionService;
    private final UserContext userContext;
    private final com.institute.lms.repository.BatchRepository batchRepository;
    private final com.institute.lms.repository.PlacementDriveRepository placementDriveRepository;
    private final com.institute.lms.repository.NotificationRepository notificationRepository;
    private final com.institute.lms.service.FcmService fcmService;

    public InterviewRoomController(InterviewSessionRepository sessionRepository,
                                   InterviewSlotRepository slotRepository,
                                   UserRepository userRepository,
                                   HundredMsService hundredMsService,
                                   CodeExecutionService codeExecutionService,
                                   UserContext userContext,
                                   com.institute.lms.repository.BatchRepository batchRepository,
                                   com.institute.lms.repository.PlacementDriveRepository placementDriveRepository,
                                   com.institute.lms.repository.NotificationRepository notificationRepository,
                                   com.institute.lms.service.FcmService fcmService) {
        this.sessionRepository = sessionRepository;
        this.slotRepository = slotRepository;
        this.userRepository = userRepository;
        this.hundredMsService = hundredMsService;
        this.codeExecutionService = codeExecutionService;
        this.userContext = userContext;
        this.batchRepository = batchRepository;
        this.placementDriveRepository = placementDriveRepository;
        this.notificationRepository = notificationRepository;
        this.fcmService = fcmService;
    }

    /**
     * Creates or initializes a 1-on-1 interview room with 100ms video calling credentials.
     */
    @PostMapping("/rooms")
    public ResponseEntity<Map<String, Object>> createOrJoinRoom(@RequestBody Map<String, Object> payload) {
        String roomCode = payload.get("roomCode") != null ? String.valueOf(payload.get("roomCode")).trim() : null;
        Long slotId = payload.get("slotId") != null ? ((Number) payload.get("slotId")).longValue() : null;

        InterviewSession session = null;
        if (roomCode != null && !roomCode.isBlank()) {
            session = sessionRepository.findByRoomCode(roomCode).orElse(null);
        }
        if (session == null && slotId != null) {
            session = sessionRepository.findBySlotId(slotId).orElse(null);
        }

        if (session == null) {
            session = new InterviewSession();
            String generatedCode = (roomCode != null && !roomCode.isBlank())
                    ? roomCode
                    : "AXIS-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase();
            session.setRoomCode(generatedCode);
            session.setTitle(payload.getOrDefault("title", "1-on-1 Technical Interview").toString());
            session.setSlotId(slotId);

            if (slotId != null) {
                InterviewSlot slot = slotRepository.findById(slotId).orElse(null);
                if (slot != null) {
                    session.setDriveId(slot.getDriveId());
                    session.setCandidateId(slot.getBookedByUserId());
                    session.setScheduledAt(slot.getSlotTime());
                    session.setInterviewerId(slot.getFacultyId());
                    session.setInterviewerName(slot.getFacultyName());
                    session.setInterviewerEmail(slot.getFacultyEmail());
                    if (slot.getOrganizationId() != null) {
                        session.setOrganizationId(slot.getOrganizationId());
                    }
                    if (slot.getBookedByUserId() != null) {
                        User candUser = userRepository.findById(slot.getBookedByUserId()).orElse(null);
                        if (candUser != null) {
                            session.setCandidateName(candUser.getName());
                            session.setCandidateEmail(candUser.getEmail());
                        }
                    }
                    if (slot.getFacultyId() != null) {
                        User fac = userRepository.findById(slot.getFacultyId()).orElse(null);
                        if (fac != null) {
                            session.setInterviewerName(fac.getName());
                            session.setInterviewerEmail(fac.getEmail());
                        }
                    }
                }
            }

            if (payload.get("candidateId") != null) {
                Long cid = ((Number) payload.get("candidateId")).longValue();
                session.setCandidateId(cid);
                User candUser = userRepository.findById(cid).orElse(null);
                if (candUser != null) {
                    session.setCandidateName(candUser.getName());
                    session.setCandidateEmail(candUser.getEmail());
                }
            }
            if (payload.get("candidateName") != null) {
                session.setCandidateName(String.valueOf(payload.get("candidateName")));
            }
            if (payload.get("interviewerId") != null) {
                Long iid = ((Number) payload.get("interviewerId")).longValue();
                session.setInterviewerId(iid);
                User fac = userRepository.findById(iid).orElse(null);
                if (fac != null) {
                    session.setInterviewerName(fac.getName());
                    session.setInterviewerEmail(fac.getEmail());
                }
            }
            if (payload.get("interviewerName") != null) {
                session.setInterviewerName(String.valueOf(payload.get("interviewerName")));
            }
            if (payload.get("interviewerEmail") != null) {
                session.setInterviewerEmail(String.valueOf(payload.get("interviewerEmail")));
            }

            // 100ms metadata
            String hmsRoomId = "hms-room-" + session.getRoomCode().toLowerCase();
            session.setHmsRoomId(hmsRoomId);
            session.setHmsRoomCode(session.getRoomCode().toLowerCase());
            session.setHmsMeetingUrl(hundredMsService.buildMeetingUrl(session.getRoomCode().toLowerCase(), hmsRoomId, null));
            session.setStatus("LIVE");
            session.setStartedAt(LocalDateTime.now());

            // Initialize with default interview problem if not present
            Map<String, Object> defaultProblem = getDefaultInterviewProblem(0);
            session.setProblemId(((Number) defaultProblem.get("id")).longValue());
            session.setProblemTitle((String) defaultProblem.get("title"));
            session.setProblemDifficulty((String) defaultProblem.get("difficulty"));
            session.setProblemDescription((String) defaultProblem.get("description"));
            session.setCodeLanguage("java");
            session.setSubmittedCode((String) defaultProblem.get("starterCodeJava"));

            session = sessionRepository.save(session);
        } else {
            boolean updated = false;
            if (payload.get("candidateId") != null && session.getCandidateId() == null) {
                Long cid = ((Number) payload.get("candidateId")).longValue();
                session.setCandidateId(cid);
                User candUser = userRepository.findById(cid).orElse(null);
                if (candUser != null) {
                    session.setCandidateName(candUser.getName());
                    session.setCandidateEmail(candUser.getEmail());
                }
                updated = true;
            }
            try {
                User current = userContext.currentUser();
                if (current != null && current.getRole() == User.UserRole.STUDENT) {
                    if (session.getCandidateId() == null) {
                        session.setCandidateId(current.getId());
                        session.setCandidateName(current.getName());
                        session.setCandidateEmail(current.getEmail());
                        updated = true;
                    }
                }
            } catch (Exception ignored) {}

            if (updated) {
                session = sessionRepository.save(session);
            }
        }

        return ResponseEntity.ok(buildRoomResponse(session));
    }

    /**
     * Fetches current state of the interview room by room code.
     */
    @GetMapping("/rooms/{roomCode}")
    public ResponseEntity<Map<String, Object>> getRoom(@PathVariable String roomCode) {
        return sessionRepository.findByRoomCode(roomCode)
                .map(s -> ResponseEntity.ok(buildRoomResponse(s)))
                .orElseGet(() -> {
                    // Create on-the-fly room for testing if doesn't exist
                    InterviewSession newSession = new InterviewSession();
                    newSession.setRoomCode(roomCode);
                    newSession.setTitle("1-on-1 Technical Interview (" + roomCode + ")");
                    newSession.setHmsRoomId("hms-" + roomCode.toLowerCase());
                    newSession.setHmsRoomCode(roomCode.toLowerCase());
                    newSession.setHmsMeetingUrl(hundredMsService.buildMeetingUrl(roomCode.toLowerCase(), "hms-" + roomCode.toLowerCase(), null));
                    newSession.setStatus("LIVE");
                    newSession.setStartedAt(LocalDateTime.now());

                    Map<String, Object> prob = getDefaultInterviewProblem(0);
                    newSession.setProblemId(1L);
                    newSession.setProblemTitle((String) prob.get("title"));
                    newSession.setProblemDifficulty((String) prob.get("difficulty"));
                    newSession.setProblemDescription((String) prob.get("description"));
                    newSession.setCodeLanguage("java");
                    newSession.setSubmittedCode((String) prob.get("starterCodeJava"));

                    InterviewSession saved = sessionRepository.save(newSession);
                    return ResponseEntity.ok(buildRoomResponse(saved));
                });
    }

    /**
     * Submits interviewer rubric ratings, hire/reject decision, and evaluation notes.
     */
    @PostMapping("/rooms/{roomCode}/evaluation")
    public ResponseEntity<Map<String, Object>> submitEvaluation(
            @PathVariable String roomCode,
            @RequestBody Map<String, Object> eval) {

        InterviewSession session = sessionRepository.findByRoomCode(roomCode)
                .orElseThrow(() -> new RuntimeException("Interview room not found: " + roomCode));

        if (eval.get("problemSolvingScore") != null) {
            session.setProblemSolvingScore(((Number) eval.get("problemSolvingScore")).intValue());
        }
        if (eval.get("technicalCompetencyScore") != null) {
            session.setTechnicalCompetencyScore(((Number) eval.get("technicalCompetencyScore")).intValue());
        }
        if (eval.get("codeQualityScore") != null) {
            session.setCodeQualityScore(((Number) eval.get("codeQualityScore")).intValue());
        }
        if (eval.get("communicationScore") != null) {
            session.setCommunicationScore(((Number) eval.get("communicationScore")).intValue());
        }
        if (eval.get("hiringDecision") != null) {
            session.setHiringDecision(String.valueOf(eval.get("hiringDecision")));
        }
        if (eval.get("interviewerNotes") != null) {
            session.setInterviewerNotes(String.valueOf(eval.get("interviewerNotes")));
        }
        if (eval.get("submittedCode") != null) {
            session.setSubmittedCode(String.valueOf(eval.get("submittedCode")));
        }
        if (eval.get("codeLanguage") != null) {
            session.setCodeLanguage(String.valueOf(eval.get("codeLanguage")));
        }
        if (Boolean.TRUE.equals(eval.get("finalize"))) {
            session.setStatus("COMPLETED");
            session.setEndedAt(LocalDateTime.now());
        }

        InterviewSession saved = sessionRepository.save(session);

        // Notify student if evaluation completed/saved
        if (saved.getCandidateId() != null && (saved.getHiringDecision() != null || "COMPLETED".equals(saved.getStatus()))) {
            userRepository.findById(saved.getCandidateId()).ifPresent(cand -> {
                com.institute.lms.entity.Notification notif = new com.institute.lms.entity.Notification();
                notif.setUserId(cand.getId());
                notif.setTitle("Interview Evaluation Available: " + saved.getTitle());
                notif.setMessage("Your 1-on-1 interview feedback has been submitted by "
                        + (saved.getInterviewerName() != null ? saved.getInterviewerName() : "your interviewer")
                        + ". Recommendation: " + (saved.getHiringDecision() != null ? saved.getHiringDecision() : "Evaluated"));
                notif.setType("INTERVIEW_FEEDBACK");
                notif.setActionUrl("/interview-feedback");
                notificationRepository.save(notif);

                if (cand.getFcmToken() != null && !cand.getFcmToken().isBlank()) {
                    fcmService.sendToToken(cand.getFcmToken(), "Interview Feedback Available",
                            "Evaluation submitted for " + saved.getTitle(), Map.of("roomCode", saved.getRoomCode()));
                }
            });
        }

        return ResponseEntity.ok(Map.of(
                "success", true,
                "message", "Interview evaluation submitted successfully",
                "roomCode", saved.getRoomCode(),
                "status", saved.getStatus(),
                "hiringDecision", saved.getHiringDecision() != null ? saved.getHiringDecision() : "PENDING"
        ));
    }

    /**
     * Lists interviews filtered by role, batch scope, and time filter.
     * Clears completed interviews after 24 hours (Requirement 8).
     */
    @GetMapping
    public ResponseEntity<List<Map<String, Object>>> getInterviews(
            @RequestParam(required = false) String scope,
            @RequestParam(required = false) String filter,
            @RequestParam(required = false) String status) {

        User current = userContext.currentUser();
        List<InterviewSession> allSessions = sessionRepository.findAll();

        // 1. Scoping by role
        List<InterviewSession> scoped;
        if (userContext.isAnyAdmin()) {
            scoped = allSessions;
        } else if (userContext.isFaculty()) {
            if ("batch".equalsIgnoreCase(scope)) {
                List<Long> batchIds = userContext.facultyBatchIds();
                Set<Long> studentIdsInBatches = new HashSet<>();
                for (Long bId : batchIds) {
                    userRepository.findByRoleAndBatchId(User.UserRole.STUDENT, bId)
                            .forEach(s -> studentIdsInBatches.add(s.getId()));
                }
                scoped = allSessions.stream()
                        .filter(s -> s.getCandidateId() != null && studentIdsInBatches.contains(s.getCandidateId()))
                        .toList();
            } else {
                Long facId = current != null ? current.getId() : -1L;
                scoped = allSessions.stream()
                        .filter(s -> Objects.equals(s.getInterviewerId(), facId))
                        .toList();
            }
        } else {
            Long studentId = current != null ? current.getId() : -1L;
            scoped = allSessions.stream()
                    .filter(s -> Objects.equals(s.getCandidateId(), studentId))
                    .toList();
        }

        // 2. Requirement 8: Clear completed interviews after 24 hours
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime cutoff = now.minusHours(24);
        scoped = scoped.stream().filter(s -> {
            if ("COMPLETED".equalsIgnoreCase(s.getStatus()) && s.getEndedAt() != null) {
                return !s.getEndedAt().isBefore(cutoff);
            }
            return true;
        }).toList();

        // 3. Time filter (all, upcoming, today, past)
        if (filter != null && !filter.isBlank() && !"all".equalsIgnoreCase(filter)) {
            scoped = scoped.stream().filter(s -> {
                LocalDateTime sched = s.getScheduledAt() != null ? s.getScheduledAt() : s.getCreatedAt();
                if (sched == null) return true;
                if ("upcoming".equalsIgnoreCase(filter)) {
                    return "SCHEDULED".equalsIgnoreCase(s.getStatus()) || "LIVE".equalsIgnoreCase(s.getStatus()) || sched.isAfter(now);
                } else if ("today".equalsIgnoreCase(filter)) {
                    return sched.toLocalDate().isEqual(now.toLocalDate());
                } else if ("past".equalsIgnoreCase(filter)) {
                    return sched.isBefore(now) && !"LIVE".equalsIgnoreCase(s.getStatus()) && !"SCHEDULED".equalsIgnoreCase(s.getStatus());
                }
                return true;
            }).toList();
        }

        if (status != null && !status.isBlank() && !"all".equalsIgnoreCase(status)) {
            scoped = scoped.stream().filter(s -> status.equalsIgnoreCase(s.getStatus())).toList();
        }

        scoped = scoped.stream()
                .sorted(Comparator.comparing((InterviewSession s) ->
                        s.getScheduledAt() != null ? s.getScheduledAt() : (s.getCreatedAt() != null ? s.getCreatedAt() : LocalDateTime.MIN)
                ).reversed())
                .toList();

        List<Map<String, Object>> result = scoped.stream().map(this::toDetailedInterviewDTO).toList();
        return ResponseEntity.ok(result);
    }

    /**
     * Permanent feedback query for student portal (never expires after 24h).
     */
    @GetMapping("/feedback")
    public ResponseEntity<List<Map<String, Object>>> getInterviewFeedbacks(
            @RequestParam(required = false) Long studentId) {

        User current = userContext.currentUser();
        Long targetStudentId = studentId;
        if (targetStudentId == null && current != null && current.getRole() == User.UserRole.STUDENT) {
            targetStudentId = current.getId();
        }

        List<InterviewSession> allSessions = sessionRepository.findAll();
        final Long fStudentId = targetStudentId;
        List<InterviewSession> evaluated = allSessions.stream()
                .filter(s -> (fStudentId == null || Objects.equals(s.getCandidateId(), fStudentId)))
                .filter(s -> s.getHiringDecision() != null || s.getProblemSolvingScore() != null || "COMPLETED".equalsIgnoreCase(s.getStatus()))
                .sorted(Comparator.comparing((InterviewSession s) ->
                        s.getEndedAt() != null ? s.getEndedAt() : (s.getCreatedAt() != null ? s.getCreatedAt() : LocalDateTime.MIN)
                ).reversed())
                .toList();

        List<Map<String, Object>> result = evaluated.stream().map(this::toDetailedInterviewDTO).toList();
        return ResponseEntity.ok(result);
    }

    private Map<String, Object> toDetailedInterviewDTO(InterviewSession session) {
        Map<String, Object> map = new HashMap<>();
        map.put("id", session.getId());
        map.put("roomCode", session.getRoomCode());
        map.put("title", session.getTitle());
        map.put("status", session.getStatus());
        map.put("slotId", session.getSlotId());
        map.put("driveId", session.getDriveId());
        map.put("candidateId", session.getCandidateId());
        map.put("candidateName", session.getCandidateName() != null ? session.getCandidateName() : "Student Candidate");
        map.put("candidateEmail", session.getCandidateEmail() != null ? session.getCandidateEmail() : "");
        map.put("interviewerId", session.getInterviewerId());
        map.put("interviewerName", session.getInterviewerName() != null ? session.getInterviewerName() : "Faculty Interviewer");
        map.put("scheduledAt", session.getScheduledAt());
        map.put("startedAt", session.getStartedAt());
        map.put("endedAt", session.getEndedAt());
        map.put("hmsMeetingUrl", session.getHmsMeetingUrl());

        // Rubric details
        map.put("problemId", session.getProblemId());
        map.put("problemTitle", session.getProblemTitle() != null ? session.getProblemTitle() : "Two Sum");
        map.put("problemDifficulty", session.getProblemDifficulty() != null ? session.getProblemDifficulty() : "Easy");
        map.put("codeLanguage", session.getCodeLanguage() != null ? session.getCodeLanguage() : "java");
        map.put("submittedCode", session.getSubmittedCode());
        map.put("problemSolvingScore", session.getProblemSolvingScore());
        map.put("technicalCompetencyScore", session.getTechnicalCompetencyScore());
        map.put("codeQualityScore", session.getCodeQualityScore());
        map.put("communicationScore", session.getCommunicationScore());
        map.put("hiringDecision", session.getHiringDecision());
        map.put("interviewerNotes", session.getInterviewerNotes());

        // Drive information lookup
        if (session.getDriveId() != null) {
            placementDriveRepository.findById(session.getDriveId()).ifPresent(d -> {
                map.put("companyName", d.getCompanyName());
                map.put("role", d.getRole());
                map.put("location", d.getLocation());
            });
        }

        // Student batch / phone / email real-time lookup
        if (session.getCandidateId() != null) {
            userRepository.findById(session.getCandidateId()).ifPresent(cand -> {
                map.put("candidateName", cand.getName());
                map.put("candidateEmail", cand.getEmail());
                map.put("candidatePhone", cand.getPhone());
                if (cand.getBatchId() != null) {
                    batchRepository.findById(cand.getBatchId()).ifPresent(b -> map.put("batchName", b.getName()));
                }
            });
        }

        // Faculty real-time lookup
        Long resolvedFacultyId = session.getInterviewerId();
        if (resolvedFacultyId == null && session.getSlotId() != null) {
            InterviewSlot sl = slotRepository.findById(session.getSlotId()).orElse(null);
            if (sl != null && sl.getFacultyId() != null) {
                resolvedFacultyId = sl.getFacultyId();
            }
        }
        if (resolvedFacultyId == null && session.getDriveId() != null) {
            PlacementDrive dr = placementDriveRepository.findById(session.getDriveId()).orElse(null);
            if (dr != null && dr.getAssignedFacultyId() != null) {
                resolvedFacultyId = dr.getAssignedFacultyId();
            }
        }

        if (resolvedFacultyId != null) {
            userRepository.findById(resolvedFacultyId).ifPresent(fac -> {
                map.put("interviewerId", fac.getId());
                map.put("interviewerName", fac.getName());
                map.put("interviewerEmail", fac.getEmail());
            });
        }
        if (!map.containsKey("interviewerEmail") || map.get("interviewerEmail") == null || map.get("interviewerEmail").toString().isBlank()) {
            if (session.getInterviewerEmail() != null && !session.getInterviewerEmail().isBlank()) {
                map.put("interviewerEmail", session.getInterviewerEmail());
            } else if (session.getSlotId() != null) {
                slotRepository.findById(session.getSlotId()).ifPresent(sl -> {
                    if (sl.getFacultyEmail() != null) map.put("interviewerEmail", sl.getFacultyEmail());
                });
            }
        }

        return map;
    }

    /**
     * Real-time code execution endpoint for the in-room collaborative code editor.
     */
    @PostMapping("/rooms/{roomCode}/execute")
    public ResponseEntity<Map<String, Object>> executeCode(
            @PathVariable String roomCode,
            @RequestBody Map<String, Object> req) {

        String language = req.getOrDefault("language", "java").toString();
        String code = req.getOrDefault("code", "").toString();
        String customInput = req.getOrDefault("input", "").toString();

        // Update current submitted code on the session
        sessionRepository.findByRoomCode(roomCode).ifPresent(s -> {
            s.setCodeLanguage(language);
            s.setSubmittedCode(code);
            sessionRepository.save(s);
        });

        long start = System.currentTimeMillis();
        CodeExecutionService.TestCaseRun runResult = codeExecutionService.executeCustomInput(language, code, customInput);
        long elapsed = System.currentTimeMillis() - start;

        Map<String, Object> response = new HashMap<>();
        response.put("status", runResult.status != null ? runResult.status.name() : "SUCCESS");
        response.put("passed", runResult.passed);
        response.put("output", runResult.actualOutput != null ? runResult.actualOutput : "");
        response.put("error", runResult.error != null ? runResult.error : "");
        response.put("executionTimeMs", runResult.executionTimeMs > 0 ? runResult.executionTimeMs : elapsed);

        return ResponseEntity.ok(response);
    }

    /**
     * Curated Question Bank for technical interview rounds.
     */
    @GetMapping("/questions")
    public ResponseEntity<List<Map<String, Object>>> getInterviewQuestions() {
        return ResponseEntity.ok(getAllInterviewProblems());
    }

    // --- Presence, Signaling, Real-time Code & Chat Sync ---

    private final Map<String, Map<String, Long>> roomHeartbeats = new java.util.concurrent.ConcurrentHashMap<>();
    private final Map<String, Map<String, String>> roomParticipantNames = new java.util.concurrent.ConcurrentHashMap<>();
    private final Map<String, List<Map<String, Object>>> roomChat = new java.util.concurrent.ConcurrentHashMap<>();
    private final Map<String, List<Map<String, Object>>> roomSignals = new java.util.concurrent.ConcurrentHashMap<>();
    private final Map<String, Map<String, Object>> roomCodeState = new java.util.concurrent.ConcurrentHashMap<>();

    @PostMapping("/rooms/{roomCode}/presence")
    public ResponseEntity<Map<String, Object>> updatePresence(
            @PathVariable String roomCode,
            @RequestBody Map<String, Object> req) {

        String role = req.getOrDefault("role", "candidate").toString().toLowerCase();
        String name = req.getOrDefault("name", role.equals("interviewer") ? "Interviewer" : "Candidate").toString();

        long now = System.currentTimeMillis();
        roomHeartbeats.computeIfAbsent(roomCode, k -> new java.util.concurrent.ConcurrentHashMap<>()).put(role, now);
        roomParticipantNames.computeIfAbsent(roomCode, k -> new java.util.concurrent.ConcurrentHashMap<>()).put(role, name);

        return ResponseEntity.ok(getPresenceInternal(roomCode));
    }

    @GetMapping("/rooms/{roomCode}/presence")
    public ResponseEntity<Map<String, Object>> getPresence(@PathVariable String roomCode) {
        return ResponseEntity.ok(getPresenceInternal(roomCode));
    }

    private Map<String, Object> getPresenceInternal(String roomCode) {
        long now = System.currentTimeMillis();
        Map<String, Long> heartbeats = roomHeartbeats.getOrDefault(roomCode, Collections.emptyMap());
        Map<String, String> names = roomParticipantNames.getOrDefault(roomCode, Collections.emptyMap());

        boolean intOnline = (now - heartbeats.getOrDefault("interviewer", 0L)) < 15000;
        boolean candOnline = (now - heartbeats.getOrDefault("candidate", 0L)) < 15000;

        String status = (intOnline && candOnline) ? "CONNECTED" : ((intOnline || candOnline) ? "WAITING" : "OFFLINE");

        Map<String, Object> res = new HashMap<>();
        res.put("roomCode", roomCode);
        res.put("status", status);
        res.put("interviewerOnline", intOnline);
        res.put("candidateOnline", candOnline);
        res.put("interviewerName", names.getOrDefault("interviewer", "Lead Interviewer"));
        res.put("candidateName", names.getOrDefault("candidate", "Candidate"));
        res.put("activeCount", (intOnline ? 1 : 0) + (candOnline ? 1 : 0));
        return res;
    }

    @PostMapping("/rooms/{roomCode}/signal")
    public ResponseEntity<Map<String, Object>> postSignal(
            @PathVariable String roomCode,
            @RequestBody Map<String, Object> signal) {

        List<Map<String, Object>> signals = roomSignals.computeIfAbsent(roomCode, k -> new java.util.concurrent.CopyOnWriteArrayList<>());
        signal.put("timestamp", System.currentTimeMillis());
        signals.add(signal);

        // Keep last 50 signals max
        if (signals.size() > 50) {
            signals.remove(0);
        }

        return ResponseEntity.ok(Map.of("success", true));
    }

    @GetMapping("/rooms/{roomCode}/signal")
    public ResponseEntity<List<Map<String, Object>>> getSignals(
            @PathVariable String roomCode,
            @RequestParam(required = false) String role,
            @RequestParam(defaultValue = "0") Long since) {

        List<Map<String, Object>> signals = roomSignals.getOrDefault(roomCode, Collections.emptyList());
        List<Map<String, Object>> filtered = new ArrayList<>();

        for (Map<String, Object> s : signals) {
            Long ts = s.get("timestamp") != null ? ((Number) s.get("timestamp")).longValue() : 0L;
            if (ts > since) {
                String toRole = String.valueOf(s.get("to"));
                if (role == null || role.isBlank() || role.equalsIgnoreCase(toRole)) {
                    filtered.add(s);
                }
            }
        }

        return ResponseEntity.ok(filtered);
    }

    @PostMapping("/rooms/{roomCode}/code")
    public ResponseEntity<Map<String, Object>> syncCode(
            @PathVariable String roomCode,
            @RequestBody Map<String, Object> req) {

        String code = req.getOrDefault("code", "").toString();
        String language = req.getOrDefault("language", "java").toString();

        Map<String, Object> state = new HashMap<>();
        state.put("code", code);
        state.put("language", language);
        state.put("updatedAt", System.currentTimeMillis());
        roomCodeState.put(roomCode, state);

        sessionRepository.findByRoomCode(roomCode).ifPresent(s -> {
            s.setSubmittedCode(code);
            s.setCodeLanguage(language);
            sessionRepository.save(s);
        });

        return ResponseEntity.ok(Map.of("success", true));
    }

    @GetMapping("/rooms/{roomCode}/code")
    public ResponseEntity<Map<String, Object>> getSyncedCode(@PathVariable String roomCode) {
        Map<String, Object> state = roomCodeState.get(roomCode);
        if (state != null) {
            return ResponseEntity.ok(state);
        }
        return sessionRepository.findByRoomCode(roomCode)
                .map(s -> ResponseEntity.ok(Map.<String, Object>of(
                        "code", s.getSubmittedCode() != null ? s.getSubmittedCode() : "",
                        "language", s.getCodeLanguage() != null ? s.getCodeLanguage() : "java",
                        "updatedAt", System.currentTimeMillis()
                )))
                .orElse(ResponseEntity.ok(Map.of("code", "", "language", "java")));
    }

    @PostMapping("/rooms/{roomCode}/chat")
    public ResponseEntity<Map<String, Object>> sendChat(
            @PathVariable String roomCode,
            @RequestBody Map<String, Object> message) {

        List<Map<String, Object>> chat = roomChat.computeIfAbsent(roomCode, k -> new java.util.concurrent.CopyOnWriteArrayList<>());
        message.put("id", UUID.randomUUID().toString());
        message.put("timestamp", System.currentTimeMillis());
        chat.add(message);

        return ResponseEntity.ok(Map.of("success", true, "message", message));
    }

    @GetMapping("/rooms/{roomCode}/chat")
    public ResponseEntity<List<Map<String, Object>>> getChat(
            @PathVariable String roomCode,
            @RequestParam(defaultValue = "0") Long since) {

        List<Map<String, Object>> chat = roomChat.getOrDefault(roomCode, Collections.emptyList());
        if (since == 0) {
            return ResponseEntity.ok(chat);
        }
        List<Map<String, Object>> newer = new ArrayList<>();
        for (Map<String, Object> m : chat) {
            Long ts = m.get("timestamp") != null ? ((Number) m.get("timestamp")).longValue() : 0L;
            if (ts > since) {
                newer.add(m);
            }
        }
        return ResponseEntity.ok(newer);
    }

    // --- Helper Methods ---

    private Map<String, Object> buildRoomResponse(InterviewSession session) {
        String candToken = hundredMsService.generateClientToken(
                session.getHmsRoomId(),
                session.getCandidateId() != null ? "user_" + session.getCandidateId() : "candidate_" + session.getRoomCode(),
                "candidate"
        );
        String intToken = hundredMsService.generateClientToken(
                session.getHmsRoomId(),
                session.getInterviewerId() != null ? "user_" + session.getInterviewerId() : "interviewer_" + session.getRoomCode(),
                "interviewer"
        );

        Map<String, Object> res = new HashMap<>();
        res.put("id", session.getId());
        res.put("roomCode", session.getRoomCode());
        res.put("title", session.getTitle());
        res.put("status", session.getStatus());
        res.put("slotId", session.getSlotId());
        res.put("candidateId", session.getCandidateId());
        res.put("candidateName", session.getCandidateName() != null ? session.getCandidateName() : "Candidate");
        res.put("candidateEmail", session.getCandidateEmail());
        if (session.getCandidateId() != null) {
            userRepository.findById(session.getCandidateId()).ifPresent(candUser -> {
                res.put("candidateName", candUser.getName());
                if (candUser.getEmail() != null) res.put("candidateEmail", candUser.getEmail());
                if (candUser.getPhone() != null) res.put("candidatePhone", candUser.getPhone());
                if (candUser.getBatchId() != null) {
                    batchRepository.findById(candUser.getBatchId()).ifPresent(b -> res.put("batchName", b.getName()));
                }
            });
        }

        Long facId = session.getInterviewerId();
        String facName = session.getInterviewerName();
        String facEmail = session.getInterviewerEmail();
        if (facId == null && session.getSlotId() != null) {
            InterviewSlot sl = slotRepository.findById(session.getSlotId()).orElse(null);
            if (sl != null && sl.getFacultyId() != null) facId = sl.getFacultyId();
        }
        if (facId != null) {
            User fac = userRepository.findById(facId).orElse(null);
            if (fac != null) {
                facName = fac.getName();
                facEmail = fac.getEmail();
            }
        }
        res.put("interviewerId", facId);
        res.put("interviewerName", facName != null ? facName : "Lead Interviewer");
        res.put("interviewerEmail", facEmail != null ? facEmail : "");
        res.put("scheduledAt", session.getScheduledAt());
        res.put("startedAt", session.getStartedAt());
        res.put("endedAt", session.getEndedAt());

        // 100ms Realtime Tokens & URLs
        res.put("hmsRoomId", session.getHmsRoomId());
        res.put("hmsRoomCode", session.getHmsRoomCode());
        res.put("hmsMeetingUrl", session.getHmsMeetingUrl());
        res.put("candidateToken", candToken);
        res.put("interviewerToken", intToken);
        res.put("subdomain", hundredMsService.getSubdomain());

        // Problem & Editor State
        res.put("problemId", session.getProblemId());
        res.put("problemTitle", session.getProblemTitle());
        res.put("problemDifficulty", session.getProblemDifficulty());
        res.put("problemDescription", session.getProblemDescription());
        res.put("codeLanguage", session.getCodeLanguage() != null ? session.getCodeLanguage() : "java");
        res.put("submittedCode", session.getSubmittedCode());

        // Rubric Scores
        res.put("problemSolvingScore", session.getProblemSolvingScore());
        res.put("technicalCompetencyScore", session.getTechnicalCompetencyScore());
        res.put("codeQualityScore", session.getCodeQualityScore());
        res.put("communicationScore", session.getCommunicationScore());
        res.put("hiringDecision", session.getHiringDecision());
        res.put("interviewerNotes", session.getInterviewerNotes());

        return res;
    }

    private static final List<Map<String, Object>> CURATED_PROBLEMS = List.of(
            Map.of(
                    "id", 1L,
                    "title", "Two Sum - Target Pair",
                    "difficulty", "Easy",
                    "category", "Data Structures & Algorithms",
                    "description", "Given an array of integers `nums` and an integer `target`, return indices of the two numbers such that they add up to `target`.\n\nYou may assume that each input would have exactly one solution, and you may not use the same element twice.\n\n**Example 1:**\n```\nInput: nums = [2,7,11,15], target = 9\nOutput: [0,1]\nExplanation: Because nums[0] + nums[1] == 9, we return [0, 1].\n```\n\n**Example 2:**\n```\nInput: nums = [3,2,4], target = 6\nOutput: [1,2]\n```\n\n**Constraints:**\n- 2 <= nums.length <= 10^4\n- -10^9 <= nums[i] <= 10^9\n- Only one valid answer exists.",
                    "starterCodeJava", "import java.util.*;\n\npublic class Solution {\n    public static int[] twoSum(int[] nums, int target) {\n        // Write your solution here\n        Map<Integer, Integer> map = new HashMap<>();\n        for (int i = 0; i < nums.length; i++) {\n            int complement = target - nums[i];\n            if (map.containsKey(complement)) {\n                return new int[] { map.get(complement), i };\n            }\n            map.put(nums[i], i);\n        }\n        return new int[] {};\n    }\n\n    public static void main(String[] args) {\n        int[] nums = {2, 7, 11, 15};\n        int target = 9;\n        int[] res = twoSum(nums, target);\n        System.out.println(\"[\" + res[0] + \", \" + res[1] + \"]\");\n    }\n}\n",
                    "starterCodePython", "def two_sum(nums, target):\n    # Write your solution here\n    seen = {}\n    for i, num in enumerate(nums):\n        complement = target - num\n        if complement in seen:\n            return [seen[complement], i]\n        seen[num] = i\n    return []\n\nif __name__ == '__main__':\n    nums = [2, 7, 11, 15]\n    target = 9\n    print(two_sum(nums, target))\n"
            ),
            Map.of(
                    "id", 2L,
                    "title", "Valid Parentheses",
                    "difficulty", "Easy",
                    "category", "Stack / String",
                    "description", "Given a string `s` containing just the characters '(', ')', '{', '}', '[' and ']', determine if the input string is valid.\n\nAn input string is valid if:\n1. Open brackets must be closed by the same type of brackets.\n2. Open brackets must be closed in the correct order.\n3. Every close bracket has a corresponding open bracket of the same type.\n\n**Example:**\n```\nInput: s = \"()[]{}\"\nOutput: true\n```",
                    "starterCodeJava", "import java.util.*;\n\npublic class Solution {\n    public static boolean isValid(String s) {\n        Stack<Character> stack = new Stack<>();\n        for (char c : s.toCharArray()) {\n            if (c == '(') stack.push(')');\n            else if (c == '{') stack.push('}');\n            else if (c == '[') stack.push(']');\n            else if (stack.isEmpty() || stack.pop() != c) return false;\n        }\n        return stack.isEmpty();\n    }\n\n    public static void main(String[] args) {\n        System.out.println(isValid(\"()[]{}\"));\n    }\n}\n",
                    "starterCodePython", "def is_valid(s: str) -> bool:\n    stack = []\n    mapping = {')': '(', '}': '{', ']': '['}\n    for char in s:\n        if char in mapping:\n            top = stack.pop() if stack else '#'\n            if mapping[char] != top:\n                return False\n        else:\n            stack.append(char)\n    return not stack\n\nif __name__ == '__main__':\n    print(is_valid('()[]{}'))\n"
            ),
            Map.of(
                    "id", 3L,
                    "title", "LRU Cache Implementation",
                    "difficulty", "Medium",
                    "category", "System Design / DSA",
                    "description", "Design a data structure that follows the constraints of a **Least Recently Used (LRU) cache**.\n\nImplement the `LRUCache` class:\n- `LRUCache(int capacity)` Initialize the LRU cache with positive size capacity.\n- `int get(int key)` Return the value of the `key` if the key exists, otherwise return `-1`.\n- `void put(int key, int value)` Update the value of the `key` if the key exists. Otherwise, add the `key-value` pair to the cache. If the number of keys exceeds the `capacity` from this operation, **evict** the least recently used key.\n\nThe functions `get` and `put` must each run in `O(1)` average time complexity.",
                    "starterCodeJava", "import java.util.*;\n\npublic class Solution {\n    static class LRUCache {\n        private final int capacity;\n        private final LinkedHashMap<Integer, Integer> map;\n\n        public LRUCache(int capacity) {\n            this.capacity = capacity;\n            this.map = new LinkedHashMap<>(capacity, 0.75f, true) {\n                @Override\n                protected boolean removeEldestEntry(Map.Entry<Integer, Integer> eldest) {\n                    return size() > LRUCache.this.capacity;\n                }\n            };\n        }\n\n        public int get(int key) {\n            return map.getOrDefault(key, -1);\n        }\n\n        public void put(int key, int value) {\n            map.put(key, value);\n        }\n    }\n\n    public static void main(String[] args) {\n        LRUCache lru = new LRUCache(2);\n        lru.put(1, 1);\n        lru.put(2, 2);\n        System.out.println(lru.get(1)); // 1\n        lru.put(3, 3); // evicts key 2\n        System.out.println(lru.get(2)); // -1 (not found)\n    }\n}\n",
                    "starterCodePython", "from collections import OrderedDict\n\nclass LRUCache:\n    def __init__(self, capacity: int):\n        self.capacity = capacity\n        self.cache = OrderedDict()\n\n    def get(self, key: int) -> int:\n        if key not in self.cache:\n            return -1\n        self.cache.move_to_end(key)\n        return self.cache[key]\n\n    def put(self, key: int, value: int) -> None:\n        if key in self.cache:\n            self.cache.move_to_end(key)\n        self.cache[key] = value\n        if len(self.cache) > self.capacity:\n            self.cache.popitem(last=False)\n\nif __name__ == '__main__':\n    lru = LRUCache(2)\n    lru.put(1, 1)\n    lru.put(2, 2)\n    print(lru.get(1))\n    lru.put(3, 3)\n    print(lru.get(2))\n"
            )
    );

    private Map<String, Object> getDefaultInterviewProblem(int index) {
        if (index >= 0 && index < CURATED_PROBLEMS.size()) {
            return CURATED_PROBLEMS.get(index);
        }
        return CURATED_PROBLEMS.get(0);
    }

    private List<Map<String, Object>> getAllInterviewProblems() {
        return CURATED_PROBLEMS;
    }
}
