package com.institute.lms.controller;

import com.institute.lms.entity.Attendance;
import com.institute.lms.entity.Event;
import com.institute.lms.entity.MessagingChannel;
import com.institute.lms.entity.NotifyMedium;
import com.institute.lms.entity.User;
import com.institute.lms.repository.AttendanceRepository;
import com.institute.lms.repository.EventRepository;
import com.institute.lms.repository.UserRepository;
import com.institute.lms.service.NotificationService;
import com.institute.lms.service.OrgFeatureSettingsService;
import com.institute.lms.service.messaging.MessagingService;
import com.institute.lms.util.UserContext;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/attendance")
public class AttendanceController {

    private final AttendanceRepository attendanceRepository;
    private final EventRepository eventRepository;
    private final UserRepository userRepository;
    private final com.institute.lms.service.subscription.ActivityMeterService activityMeter;
    private final UserContext userContext;
    private final OrgFeatureSettingsService featureSettingsService;
    private final MessagingService messagingService;
    private final NotificationService notificationService;

    public AttendanceController(AttendanceRepository attendanceRepository, EventRepository eventRepository,
                                 UserRepository userRepository,
                                 com.institute.lms.service.subscription.ActivityMeterService activityMeter,
                                 UserContext userContext,
                                 OrgFeatureSettingsService featureSettingsService,
                                 MessagingService messagingService,
                                 NotificationService notificationService) {
        this.attendanceRepository = attendanceRepository;
        this.eventRepository = eventRepository;
        this.userRepository = userRepository;
        this.activityMeter = activityMeter;
        this.userContext = userContext;
        this.featureSettingsService = featureSettingsService;
        this.messagingService = messagingService;
        this.notificationService = notificationService;
    }

    /**
     * Finds (or creates) the one {@code DAILY_ATTENDANCE} event for this batch and
     * calendar day, so daily attendance reuses the existing per-event mark/grid
     * flow instead of a parallel data model. The admin UI calls this first, then
     * marks attendance on the returned event id via the existing
     * {@code /event/{id}/mark} endpoint below.
     */
    @PostMapping("/daily/{batchId}/{date}")
    public ResponseEntity<Map<String, Object>> getOrCreateDailyAttendanceEvent(
            @PathVariable Long batchId, @PathVariable String date,
            @RequestParam(required = false) String subject) {
        userContext.requireOrgAdminOrFaculty();
        String normalizedSubject = (subject != null && !subject.isBlank()) ? subject.trim() : null;
        LocalDateTime startTime = LocalDate.parse(date).atStartOfDay();
        Event event = normalizedSubject == null
                ? eventRepository.findByBatchIdAndEventTypeAndStartTime(batchId, "DAILY_ATTENDANCE", startTime)
                        .orElseGet(() -> createDailyAttendanceEvent(batchId, date, startTime, null))
                : eventRepository.findByBatchIdAndEventTypeAndStartTimeAndSubject(batchId, "DAILY_ATTENDANCE", startTime, normalizedSubject)
                        .orElseGet(() -> createDailyAttendanceEvent(batchId, date, startTime, normalizedSubject));
        Map<String, Object> response = new LinkedHashMap<>();
        response.put("eventId", event.getId());
        response.put("eventTitle", event.getTitle());
        return ResponseEntity.ok(response);
    }

    private Event createDailyAttendanceEvent(Long batchId, String date, LocalDateTime startTime, String subject) {
        Event e = new Event();
        e.setTitle("Daily Attendance - " + date + (subject != null ? " (" + subject + ")" : ""));
        e.setEventType("DAILY_ATTENDANCE");
        e.setBatchId(batchId);
        e.setStartTime(startTime);
        e.setEndTime(startTime.withHour(23).withMinute(59));
        e.setAttendanceRequired(true);
        e.setSubject(subject);
        return eventRepository.save(e);
    }

    /** All attendance records for an event, including students who are not yet marked. */
    @GetMapping("/event/{eventId}")
    public ResponseEntity<Map<String, Object>> getAttendanceForEvent(@PathVariable Long eventId) {
        Event event = eventRepository.findById(eventId).orElse(null);
        if (event == null) return ResponseEntity.notFound().build();

        List<User> students = event.getBatchId() != null
                ? userRepository.findByRoleAndBatchId(User.UserRole.STUDENT, event.getBatchId())
                : userRepository.findByRole(User.UserRole.STUDENT);

        List<Attendance> existing = attendanceRepository.findByEventId(eventId);
        Map<Long, Attendance> byUser = new LinkedHashMap<>();
        for (Attendance a : existing) {
            if (a.getUser() != null) byUser.put(a.getUser().getId(), a);
        }

        List<Map<String, Object>> rows = new java.util.ArrayList<>();
        for (User student : students) {
            Attendance a = byUser.get(student.getId());
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("attendanceId", a != null ? a.getId() : null);
            row.put("userId", student.getId());
            row.put("userName", student.getName());
            row.put("present", a != null ? a.getPresent() : false);
            row.put("remarks", a != null ? a.getRemarks() : null);
            rows.add(row);
        }

        Map<String, Object> response = new LinkedHashMap<>();
        response.put("eventId", eventId);
        response.put("eventTitle", event.getTitle());
        response.put("students", rows);
        return ResponseEntity.ok(response);
    }

    /** Bulk mark attendance for an event. Body: { "records": [ {"userId":1,"present":true,"remarks":""} ] } */
    @PostMapping("/event/{eventId}/mark")
    public ResponseEntity<List<Attendance>> markAttendance(@PathVariable Long eventId, @RequestBody Map<String, Object> body) {
        userContext.requireOrgAdminOrFaculty();
        Event event = eventRepository.findById(eventId).orElseThrow(() -> new RuntimeException("Event not found"));
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> records = (List<Map<String, Object>>) body.get("records");
        List<Attendance> saved = new java.util.ArrayList<>();
        if (records != null) {
            for (Map<String, Object> record : records) {
                Long userId = ((Number) record.get("userId")).longValue();
                Boolean present = Boolean.TRUE.equals(record.get("present"));
                String remarks = record.get("remarks") != null ? record.get("remarks").toString() : null;

                User user = userRepository.findById(userId).orElse(null);
                if (user == null) continue;

                Attendance attendance = attendanceRepository.findByUserIdAndEventId(userId, eventId)
                        .orElseGet(Attendance::new);
                attendance.setUser(user);
                attendance.setEvent(event);
                attendance.setPresent(present);
                attendance.setRemarks(remarks);
                saved.add(attendanceRepository.save(attendance));

                // Attending a class counts as activity for the billing month. Only
                // students actually marked present are metered — recording an absence
                // would bill an academy for a student who did not turn up.
                if (present && user.getRole() == User.UserRole.STUDENT) {
                    activityMeter.record(user.getOrganizationId(), user.getId(),
                            com.institute.lms.subscription.ActivityType.CLASS_ATTENDANCE);
                }

                if (!present && user.getRole() == User.UserRole.STUDENT) {
                    notifyAbsentee(user, event);
                }
            }
        }
        return ResponseEntity.ok(saved);
    }

    /**
     * Tells a parent their child was marked absent today, if the org has opted in.
     * Non-fatal by design (matches the existing safeNotify resilience pattern) —
     * a messaging outage must never block attendance marking.
     */
    private void notifyAbsentee(User student, Event event) {
        try {
            if (!featureSettingsService.getEffective(student.getOrganizationId()).getAttendanceNotificationsEnabled()) {
                return;
            }
            String title = "Absence recorded";
            String message = student.getName() + " was marked absent for " + event.getTitle() + " today.";
            NotifyMedium medium = student.getNotifyMedium() != null ? student.getNotifyMedium() : NotifyMedium.PUSH;

            switch (medium) {
                case SMS -> sendToParent(student, MessagingChannel.SMS, message);
                case WHATSAPP -> sendToParent(student, MessagingChannel.WHATSAPP, message);
                default -> notificationService.notifyStudents(List.of(student), title, message,
                        "attendance", "/attendance", "EVENT", event.getId());
            }
        } catch (Exception e) {
            System.err.println("Failed to send absentee notification for user "
                    + student.getId() + ": " + e.getMessage());
        }
    }

    private void sendToParent(User student, MessagingChannel channel, String message) {
        String phone = student.getParentPhone();
        if (phone == null || phone.isBlank()) return;
        messagingService.send(student.getOrganizationId(), channel, phone, message);
    }

    /** Attendance history + summary percentage for a student. */
    @GetMapping("/student/{studentId}")
    public ResponseEntity<Map<String, Object>> getAttendanceForStudent(@PathVariable Long studentId) {
        List<Attendance> records = attendanceRepository.findByUserId(studentId);
        long total = records.size();
        long present = records.stream().filter(a -> Boolean.TRUE.equals(a.getPresent())).count();
        double percentage = total > 0 ? (present * 100.0 / total) : 0.0;

        List<Map<String, Object>> history = new java.util.ArrayList<>();
        for (Attendance a : records) {
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("eventId", a.getEvent() != null ? a.getEvent().getId() : null);
            item.put("eventTitle", a.getEvent() != null ? a.getEvent().getTitle() : null);
            item.put("eventType", a.getEvent() != null ? a.getEvent().getEventType() : null);
            item.put("startTime", a.getEvent() != null ? a.getEvent().getStartTime() : null);
            item.put("subject", a.getEvent() != null ? a.getEvent().getSubject() : null);
            item.put("present", a.getPresent());
            item.put("remarks", a.getRemarks());
            history.add(item);
        }

        Map<String, Object> response = new LinkedHashMap<>();
        response.put("totalEvents", total);
        response.put("presentCount", present);
        response.put("absentCount", total - present);
        response.put("percentage", Math.round(percentage * 100.0) / 100.0);
        response.put("history", history);
        return ResponseEntity.ok(response);
    }
}
