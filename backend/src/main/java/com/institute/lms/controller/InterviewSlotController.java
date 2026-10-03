package com.institute.lms.controller;

import com.institute.lms.dto.placement.InterviewSlotAdminDTO;
import com.institute.lms.dto.placement.InterviewSlotHistoryDTO;
import com.institute.lms.entity.InterviewSlot;
import com.institute.lms.entity.PlacementDrive;
import com.institute.lms.entity.User;
import com.institute.lms.repository.InterviewSlotRepository;
import com.institute.lms.repository.PlacementDriveRepository;
import com.institute.lms.repository.UserRepository;
import com.institute.lms.service.FcmService;
import com.institute.lms.util.UserContext;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * Manages interview slots for INTERNAL placement drives: admin creates the
 * available slots, students book ("Schedule my slot") one of them, closing
 * the loop between a placement drive and actual interview tracking.
 */
@RestController
@RequestMapping("/api/interview-slots")
public class InterviewSlotController {

    private final InterviewSlotRepository interviewSlotRepository;
    private final PlacementDriveRepository placementDriveRepository;
    private final UserRepository userRepository;
    private final FcmService fcmService;
    private final UserContext userContext;
    private final com.institute.lms.repository.InterviewSessionRepository sessionRepository;
    private final com.institute.lms.repository.EventRepository eventRepository;
    private final com.institute.lms.repository.NotificationRepository notificationRepository;
    private final com.institute.lms.service.HundredMsService hundredMsService;

    public InterviewSlotController(InterviewSlotRepository interviewSlotRepository,
                                    PlacementDriveRepository placementDriveRepository,
                                    UserRepository userRepository, FcmService fcmService,
                                    UserContext userContext,
                                    com.institute.lms.repository.InterviewSessionRepository sessionRepository,
                                    com.institute.lms.repository.EventRepository eventRepository,
                                    com.institute.lms.repository.NotificationRepository notificationRepository,
                                    com.institute.lms.service.HundredMsService hundredMsService) {
        this.interviewSlotRepository = interviewSlotRepository;
        this.placementDriveRepository = placementDriveRepository;
        this.userRepository = userRepository;
        this.fcmService = fcmService;
        this.userContext = userContext;
        this.sessionRepository = sessionRepository;
        this.eventRepository = eventRepository;
        this.notificationRepository = notificationRepository;
        this.hundredMsService = hundredMsService;
    }

    /** All slots for a drive (used by both admin management and the student booking screen). */
    @GetMapping("/drive/{driveId}")
    public List<InterviewSlotAdminDTO> getSlotsForDrive(@PathVariable Long driveId) {
        List<InterviewSlot> slots = interviewSlotRepository.findByDriveIdOrderBySlotTimeAsc(driveId);
        List<Long> bookedUserIds = slots.stream()
                .map(InterviewSlot::getBookedByUserId)
                .filter(java.util.Objects::nonNull)
                .distinct()
                .toList();
        Map<Long, User> usersById = userRepository.findAllById(bookedUserIds).stream()
                .collect(Collectors.toMap(User::getId, u -> u));

        return slots.stream().map(slot -> {
            InterviewSlotAdminDTO dto = new InterviewSlotAdminDTO();
            dto.setId(slot.getId());
            dto.setDriveId(slot.getDriveId());
            dto.setLocation(slot.getLocation());
            dto.setNotes(slot.getNotes());
            dto.setSlotTime(slot.getSlotTime());
            dto.setStatus(slot.getStatus());
            dto.setBookedByUserId(slot.getBookedByUserId());
            dto.setBookedAt(slot.getBookedAt());
            dto.setFacultyId(slot.getFacultyId());
            dto.setFacultyName(slot.getFacultyName());
            dto.setFacultyEmail(slot.getFacultyEmail());
            dto.setRoomCode(slot.getRoomCode());
            User bookedBy = slot.getBookedByUserId() != null ? usersById.get(slot.getBookedByUserId()) : null;
            if (bookedBy != null) {
                dto.setBookedByName(bookedBy.getName());
                dto.setBookedByEmail(bookedBy.getEmail());
            }
            return dto;
        }).toList();
    }

    /** The student's own booked slots, across all drives, most recent first. */
    @GetMapping("/student/{studentId}")
    public List<InterviewSlotHistoryDTO> getSlotsForStudent(@PathVariable Long studentId) {
        return interviewSlotRepository.findByBookedByUserId(studentId).stream()
                .sorted(Comparator.comparing(InterviewSlot::getSlotTime).reversed())
                .map(slot -> {
                    InterviewSlotHistoryDTO dto = new InterviewSlotHistoryDTO();
                    dto.setId(slot.getId());
                    dto.setDriveId(slot.getDriveId());
                    dto.setLocation(slot.getLocation());
                    dto.setSlotTime(slot.getSlotTime());
                    dto.setStatus(slot.getStatus());
                    dto.setFacultyId(slot.getFacultyId());
                    dto.setFacultyName(slot.getFacultyName());
                    dto.setFacultyEmail(slot.getFacultyEmail());
                    dto.setRoomCode(slot.getRoomCode());
                    PlacementDrive drive = slot.getDriveId() != null
                            ? placementDriveRepository.findById(slot.getDriveId()).orElse(null)
                            : null;
                    if (drive != null) {
                        dto.setCompanyName(drive.getCompanyName());
                        dto.setRole(drive.getRole());
                    }
                    return dto;
                })
                .toList();
    }

    private LocalDateTime parseDateTime(Object raw) {
        if (raw == null) return null;
        String s = raw.toString().trim();
        if (s.isEmpty() || "null".equalsIgnoreCase(s)) return null;
        try {
            if (s.endsWith("Z")) {
                return java.time.Instant.parse(s).atZone(java.time.ZoneId.systemDefault()).toLocalDateTime();
            }
            if (s.contains("+")) {
                return java.time.OffsetDateTime.parse(s).toLocalDateTime();
            }
            if (s.length() == 16) {
                s = s + ":00";
            }
            s = s.replace(" ", "T");
            return LocalDateTime.parse(s);
        } catch (Exception e) {
            try {
                return LocalDateTime.parse(s, java.time.format.DateTimeFormatter.ISO_DATE_TIME);
            } catch (Exception ex) {
                return null;
            }
        }
    }

    /** Admin or Faculty creates a new open slot for an internal drive. */
    @PostMapping
    public ResponseEntity<?> createSlot(@RequestBody Map<String, Object> body) {
        userContext.requireOrgAdminOrFaculty();

        Long driveId = null;
        if (body.get("driveId") != null && !body.get("driveId").toString().isBlank()) {
            try {
                driveId = Long.valueOf(body.get("driveId").toString().trim());
            } catch (Exception ignored) {}
        }
        if (driveId == null) {
            return ResponseEntity.badRequest().body(Map.of("error", "driveId is required"));
        }

        PlacementDrive drive = placementDriveRepository.findById(driveId).orElse(null);
        if (drive == null) {
            return ResponseEntity.badRequest().body(Map.of("error", "Placement drive not found with id: " + driveId));
        }

        LocalDateTime slotTime = parseDateTime(body.get("slotTime"));
        if (slotTime == null) {
            return ResponseEntity.badRequest().body(Map.of("error", "Valid slotTime is required (e.g. 2026-10-15T10:00:00)"));
        }

        InterviewSlot slot = new InterviewSlot();
        slot.setDriveId(driveId);
        slot.setOrganizationId(drive.getOrganizationId());
        slot.setSlotTime(slotTime);
        slot.setLocation(body.get("location") != null && !body.get("location").toString().isBlank()
                ? String.valueOf(body.get("location")).trim()
                : (drive.getLocation() != null ? drive.getLocation() : "Online / 1-on-1 Interview Room"));
        slot.setNotes(body.get("notes") != null ? String.valueOf(body.get("notes")).trim() : null);
        slot.setStatus("AVAILABLE");

        // Faculty assignment: from request body or fall back to drive's assigned faculty
        Long facultyId = null;
        if (body.get("facultyId") != null && !body.get("facultyId").toString().isBlank() && !"null".equalsIgnoreCase(body.get("facultyId").toString())) {
            try {
                facultyId = Long.valueOf(body.get("facultyId").toString().trim());
            } catch (Exception ignored) {}
        }
        if (facultyId == null && drive.getAssignedFacultyId() != null) {
            facultyId = drive.getAssignedFacultyId();
        }

        if (facultyId != null) {
            userRepository.findById(facultyId).ifPresent(fac -> {
                slot.setFacultyId(fac.getId());
                slot.setFacultyName(fac.getName());
                slot.setFacultyEmail(fac.getEmail());
            });
        }
        if (slot.getFacultyName() == null && drive.getFacultyName() != null) {
            slot.setFacultyName(drive.getFacultyName());
        }
        if (slot.getFacultyEmail() == null && drive.getFacultyEmail() != null) {
            slot.setFacultyEmail(drive.getFacultyEmail());
        }

        return ResponseEntity.ok(interviewSlotRepository.save(slot));
    }

    /** Student books an available slot ("Schedule my slot"). */
    @PostMapping("/{id}/book")
    public ResponseEntity<?> bookSlot(@PathVariable Long id, @RequestBody(required = false) Map<String, Object> body) {
        Long userId = null;
        if (body != null && body.get("userId") != null && !body.get("userId").toString().isBlank()) {
            try {
                userId = Long.valueOf(body.get("userId").toString().trim());
            } catch (Exception ignored) {}
        }
        User user = userId != null ? userRepository.findById(userId).orElse(null) : null;
        if (user == null) {
            user = userContext.currentUser();
        }
        if (user == null) return ResponseEntity.badRequest().body(Map.of("error", "Student user not found"));

        final Long currentUserId = user.getId();
        final User currentUser = user;

        return interviewSlotRepository.findById(id)
                .map(slot -> {
                    if (!"AVAILABLE".equals(slot.getStatus())) {
                        return ResponseEntity.status(409).body(Map.of("error", "This slot is no longer available"));
                    }
                    // One slot per student per drive until an admin frees it back up.
                    boolean alreadyHasSlotOnThisDrive = !interviewSlotRepository
                            .findByDriveIdAndBookedByUserId(slot.getDriveId(), currentUserId).isEmpty();
                    if (alreadyHasSlotOnThisDrive) {
                        return ResponseEntity.status(409).body(Map.of("error", "You already have a booked slot for this drive"));
                    }

                    PlacementDrive drive = slot.getDriveId() != null
                            ? placementDriveRepository.findById(slot.getDriveId()).orElse(null)
                            : null;
                    String companyName = drive != null ? drive.getCompanyName() : "Internal Mock Drive";
                    String roleName = drive != null ? drive.getRole() : "Software Engineer";

                    String roomCode = "AXIS-INT-" + slot.getId();
                    slot.setBookedByUserId(currentUserId);
                    slot.setBookedAt(LocalDateTime.now());
                    slot.setStatus("BOOKED");
                    slot.setRoomCode(roomCode);
                    if (drive != null && drive.getOrganizationId() != null) {
                        slot.setOrganizationId(drive.getOrganizationId());
                    }

                    // Resolve faculty assignment dynamically in real time
                    Long facultyId = slot.getFacultyId();
                    if (facultyId == null && drive != null && drive.getAssignedFacultyId() != null) {
                        facultyId = drive.getAssignedFacultyId();
                        slot.setFacultyId(facultyId);
                    }
                    User facultyUser = null;
                    if (facultyId != null) {
                        facultyUser = userRepository.findById(facultyId).orElse(null);
                    }
                    String facultyName = facultyUser != null ? facultyUser.getName() : (slot.getFacultyName() != null ? slot.getFacultyName() : (drive != null && drive.getFacultyName() != null ? drive.getFacultyName() : "Faculty Interviewer"));
                    String facultyEmail = facultyUser != null ? facultyUser.getEmail() : (slot.getFacultyEmail() != null ? slot.getFacultyEmail() : (drive != null && drive.getFacultyEmail() != null ? drive.getFacultyEmail() : null));

                    slot.setFacultyName(facultyName);
                    slot.setFacultyEmail(facultyEmail);

                    InterviewSlot saved = interviewSlotRepository.save(slot);

                    // 1. Create or link the live InterviewSession
                    com.institute.lms.entity.InterviewSession session = sessionRepository.findBySlotId(slot.getId())
                            .orElseGet(com.institute.lms.entity.InterviewSession::new);
                    session.setRoomCode(roomCode);
                    session.setSlotId(slot.getId());
                    session.setDriveId(slot.getDriveId());
                    if (drive != null && drive.getOrganizationId() != null) {
                        session.setOrganizationId(drive.getOrganizationId());
                    } else if (slot.getOrganizationId() != null) {
                        session.setOrganizationId(slot.getOrganizationId());
                    }
                    session.setTitle(companyName + " - " + roleName + " Technical Interview");
                    session.setCandidateId(currentUser.getId());
                    session.setCandidateName(currentUser.getName());
                    session.setCandidateEmail(currentUser.getEmail());
                    session.setInterviewerId(facultyUser != null ? facultyUser.getId() : facultyId);
                    session.setInterviewerName(facultyName);
                    session.setInterviewerEmail(facultyEmail);
                    session.setScheduledAt(slot.getSlotTime());
                    session.setStatus("SCHEDULED");

                    String hmsRoomId = "hms-room-" + roomCode.toLowerCase();
                    session.setHmsRoomId(hmsRoomId);
                    session.setHmsRoomCode(roomCode.toLowerCase());
                    session.setHmsMeetingUrl(hundredMsService.buildMeetingUrl(roomCode.toLowerCase(), hmsRoomId, null));
                    sessionRepository.save(session);

                    // 2. Notify student via in-app Notification
                    com.institute.lms.entity.Notification notif = new com.institute.lms.entity.Notification();
                    notif.setUserId(currentUser.getId());
                    notif.setTitle("Interview Confirmed: " + companyName);
                    notif.setMessage("Your 1-on-1 interview for " + roleName + " is scheduled on " + slot.getSlotTime()
                            + (facultyName != null ? " with " + facultyName : "") + ". Studio Room: " + roomCode);
                    notif.setType("INTERVIEW");
                    notif.setActionUrl("/interview/" + roomCode);
                    notificationRepository.save(notif);

                    // 3. Add to Student Calendar (Event entity)
                    com.institute.lms.entity.Event event = new com.institute.lms.entity.Event();
                    event.setTitle("🎤 1-on-1 Interview: " + companyName + " (" + roleName + ")");
                    event.setDescription("1-on-1 Technical Mock Interview with " + facultyName + ". Room Code: " + roomCode);
                    event.setEventType("INTERVIEW");
                    event.setStartTime(slot.getSlotTime());
                    event.setEndTime(slot.getSlotTime().plusMinutes(45));
                    event.setMeetLink("/interview/" + roomCode);
                    event.setBatchId(currentUser.getBatchId());
                    event.setPlanId(currentUser.getPlanId());
                    event.setAttendanceRequired(false);
                    eventRepository.save(event);

                    // 4. Send FCM Push Notification to student
                    if (currentUser.getFcmToken() != null && !currentUser.getFcmToken().isBlank()) {
                        fcmService.sendToToken(currentUser.getFcmToken(), "Interview Slot Confirmed",
                                "Your interview slot on " + slot.getSlotTime() + " is confirmed.", Map.of("roomCode", roomCode));
                    }

                    // 5. Also notify Faculty if assigned
                    final Long finalFacultyId = facultyUser != null ? facultyUser.getId() : facultyId;
                    if (finalFacultyId != null) {
                        userRepository.findById(finalFacultyId).ifPresent(fac -> {
                            com.institute.lms.entity.Notification fn = new com.institute.lms.entity.Notification();
                            fn.setUserId(fac.getId());
                            fn.setTitle("New Interview Scheduled: " + currentUser.getName());
                            fn.setMessage("Student " + currentUser.getName() + " has booked an interview slot on "
                                    + slot.getSlotTime() + " for " + companyName + " (" + roleName + "). Room: " + roomCode);
                            fn.setType("INTERVIEW");
                            fn.setActionUrl("/interview/" + roomCode);
                            notificationRepository.save(fn);

                            if (fac.getFcmToken() != null && !fac.getFcmToken().isBlank()) {
                                fcmService.sendToToken(fac.getFcmToken(), "New Interview Scheduled",
                                        "Student " + currentUser.getName() + " scheduled an interview at " + slot.getSlotTime(),
                                        Map.of("roomCode", roomCode));
                            }
                        });
                    }

                    return ResponseEntity.ok(saved);
                })
                .orElse(ResponseEntity.notFound().build());
    }

    /** Student cancels their own booking, freeing the slot back up. */
    @PostMapping("/{id}/cancel")
    public ResponseEntity<InterviewSlot> cancelBooking(@PathVariable Long id) {
        return interviewSlotRepository.findById(id)
                .map(slot -> {
                    slot.setBookedByUserId(null);
                    slot.setBookedAt(null);
                    slot.setStatus("AVAILABLE");
                    InterviewSlot saved = interviewSlotRepository.save(slot);

                    // Mark associated session as CANCELLED
                    sessionRepository.findBySlotId(id).ifPresent(s -> {
                        s.setStatus("CANCELLED");
                        sessionRepository.save(s);
                    });

                    return ResponseEntity.ok(saved);
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @PutMapping("/{id}/status")
    public ResponseEntity<InterviewSlot> updateStatus(@PathVariable Long id, @RequestBody Map<String, String> body) {
        userContext.requireOrgAdmin();
        return interviewSlotRepository.findById(id)
                .map(slot -> {
                    slot.setStatus(body.getOrDefault("status", slot.getStatus()));
                    return ResponseEntity.ok(interviewSlotRepository.save(slot));
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteSlot(@PathVariable Long id) {
        userContext.requireOrgAdmin();
        if (!interviewSlotRepository.existsById(id)) return ResponseEntity.notFound().build();
        interviewSlotRepository.deleteById(id);
        return ResponseEntity.ok().build();
    }
}
