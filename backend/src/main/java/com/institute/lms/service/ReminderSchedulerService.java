package com.institute.lms.service;

import com.institute.lms.entity.*;
import com.institute.lms.repository.*;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

/**
 * Scheduled push-notification reminders. All timing knobs (how many hours/
 * minutes before a deadline/class to remind) are admin-configurable via
 * System Config (push.*), so behavior can be tuned without a redeploy. Each
 * reminder is deduplicated via PushNotificationLogRepository so a student is
 * never notified twice for the same assignment/exam/class/interview slot.
 */
@Service
public class ReminderSchedulerService {

    private final FcmService fcmService;
    private final SystemConfigRepository systemConfigRepository;
    private final PushNotificationLogRepository pushLogRepository;
    private final AssignmentRepository assignmentRepository;
    private final ExamRepository examRepository;
    private final EventRepository eventRepository;
    private final UserRepository userRepository;
    private final InterviewSlotRepository interviewSlotRepository;
    private final com.institute.lms.repository.NotificationRepository notificationRepository;

    public ReminderSchedulerService(FcmService fcmService, SystemConfigRepository systemConfigRepository,
                                     PushNotificationLogRepository pushLogRepository,
                                     AssignmentRepository assignmentRepository, ExamRepository examRepository,
                                     EventRepository eventRepository, UserRepository userRepository,
                                     InterviewSlotRepository interviewSlotRepository,
                                     com.institute.lms.repository.NotificationRepository notificationRepository) {
        this.fcmService = fcmService;
        this.systemConfigRepository = systemConfigRepository;
        this.pushLogRepository = pushLogRepository;
        this.assignmentRepository = assignmentRepository;
        this.examRepository = examRepository;
        this.eventRepository = eventRepository;
        this.userRepository = userRepository;
        this.interviewSlotRepository = interviewSlotRepository;
        this.notificationRepository = notificationRepository;
    }

    private long configLong(String key, long defaultValue) {
        return systemConfigRepository.findByConfigKey(key)
                .map(c -> c.getConfigValue())
                .filter(v -> v != null && !v.isBlank())
                .map(v -> {
                    try { return Long.parseLong(v.trim()); } catch (NumberFormatException e) { return defaultValue; }
                })
                .orElse(defaultValue);
    }

    private List<User> studentsForBatches(List<Long> batchIds) {
        if (batchIds == null || batchIds.isEmpty()) {
            return userRepository.findByRole(User.UserRole.STUDENT);
        }
        return userRepository.findByRole(User.UserRole.STUDENT).stream()
                .filter(u -> u.getBatchId() != null && batchIds.contains(u.getBatchId()))
                .toList();
    }

    private void notifyOnce(User student, String reminderKey, String title, String body) {
        if (pushLogRepository.existsByUserIdAndReminderKey(student.getId(), reminderKey)) return;
        if (student.getFcmToken() != null && !student.getFcmToken().isBlank()) {
            fcmService.sendToToken(student.getFcmToken(), title, body, Map.of());
        }
        PushNotificationLog log = new PushNotificationLog();
        log.setUserId(student.getId());
        log.setReminderKey(reminderKey);
        pushLogRepository.save(log);
    }

    /** Runs every 15 minutes: assignment due-date reminders. */
    @Scheduled(fixedDelay = 15 * 60 * 1000)
    public void remindUpcomingAssignments() {
        if (!fcmService.isPushEnabled()) return;
        long hoursBefore = configLong("push.assignmentReminderHoursBefore", 24);
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime windowStart = now.plusHours(hoursBefore).minusMinutes(15);
        LocalDateTime windowEnd = now.plusHours(hoursBefore);

        for (Assignment assignment : assignmentRepository.findByIsActiveTrue()) {
            if (assignment.getDueDate() == null) continue;
            if (assignment.getDueDate().isBefore(windowStart) || assignment.getDueDate().isAfter(windowEnd)) continue;
            for (User student : studentsForBatches(assignment.getBatchIds())) {
                notifyOnce(student, "assignment-" + assignment.getId(),
                        "Assignment due soon: " + assignment.getTitle(),
                        "\"" + assignment.getTitle() + "\" is due on " + assignment.getDueDate() + ". Submit before the deadline!");
            }
        }
    }

    /** Runs every 15 minutes: exam date reminders. */
    @Scheduled(fixedDelay = 15 * 60 * 1000)
    public void remindUpcomingExams() {
        if (!fcmService.isPushEnabled()) return;
        long hoursBefore = configLong("push.examReminderHoursBefore", 24);
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime windowStart = now.plusHours(hoursBefore).minusMinutes(15);
        LocalDateTime windowEnd = now.plusHours(hoursBefore);

        for (Exam exam : examRepository.findByIsActiveTrue()) {
            if (exam.getExamDate() == null) continue;
            if (exam.getExamDate().isBefore(windowStart) || exam.getExamDate().isAfter(windowEnd)) continue;
            for (User student : studentsForBatches(exam.getBatchIds())) {
                notifyOnce(student, "exam-" + exam.getId(),
                        "Exam reminder: " + exam.getTitle(),
                        "\"" + exam.getTitle() + "\" is scheduled for " + exam.getExamDate() + ". Be prepared!");
            }
        }
    }

    /** Runs every 5 minutes: live class / event reminders shortly before start. */
    @Scheduled(fixedDelay = 5 * 60 * 1000)
    public void remindUpcomingClasses() {
        if (!fcmService.isPushEnabled()) return;
        long minutesBefore = configLong("push.classReminderMinutesBefore", 30);
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime windowStart = now.plusMinutes(minutesBefore).minusMinutes(5);
        LocalDateTime windowEnd = now.plusMinutes(minutesBefore);

        for (Event event : eventRepository.findAll()) {
            if (event.getStartTime() == null) continue;
            if (event.getStartTime().isBefore(windowStart) || event.getStartTime().isAfter(windowEnd)) continue;
            List<User> students = event.getBatchId() != null
                    ? userRepository.findByRoleAndBatchId(User.UserRole.STUDENT, event.getBatchId())
                    : userRepository.findByRole(User.UserRole.STUDENT);
            for (User student : students) {
                notifyOnce(student, "event-" + event.getId(),
                        "Starting soon: " + event.getTitle(),
                        "\"" + event.getTitle() + "\" starts at " + event.getStartTime() + (event.getMeetLink() != null ? ". Tap to join." : "."));
            }
        }
    }

    /** Runs every 15 minutes: internal interview slot reminders (6 hrs, 1 hr, and 15 mins before). */
    @Scheduled(fixedDelay = 15 * 60 * 1000)
    public void remindUpcomingInterviews() {
        LocalDateTime now = LocalDateTime.now();

        // 6 hours before window
        LocalDateTime win6hStart = now.plusHours(6).minusMinutes(15);
        LocalDateTime win6hEnd = now.plusHours(6);

        // 1 hour before window
        LocalDateTime win1hStart = now.plusHours(1).minusMinutes(15);
        LocalDateTime win1hEnd = now.plusHours(1);

        // 15 minutes before window
        LocalDateTime win15mStart = now;
        LocalDateTime win15mEnd = now.plusMinutes(15);

        for (InterviewSlot slot : interviewSlotRepository.findByBookedByUserIdIsNotNull()) {
            if (slot.getSlotTime() == null || slot.getBookedByUserId() == null) continue;
            LocalDateTime st = slot.getSlotTime();

            // 6 Hours Before Check
            if (!st.isBefore(win6hStart) && !st.isAfter(win6hEnd)) {
                sendInterviewAlert(slot, "6h", "Interview in 6 Hours",
                        "Your interview is scheduled in 6 hours (" + st + "). Check your camera, mic, and IDE setup.");
            }
            // 1 Hour Before Check
            else if (!st.isBefore(win1hStart) && !st.isAfter(win1hEnd)) {
                sendInterviewAlert(slot, "1h", "Interview in 1 Hour",
                        "Your interview starts in 1 hour (" + st + "). Please be prepared.");
            }
            // 15 Minutes Before Check
            else if (!st.isBefore(win15mStart) && !st.isAfter(win15mEnd)) {
                sendInterviewAlert(slot, "15m", "Interview Starting Soon (15 min)",
                        "Your 1-on-1 interview begins in 15 minutes! Tap to enter the studio now.");
            }
        }
    }

    private void sendInterviewAlert(InterviewSlot slot, String tag, String title, String message) {
        userRepository.findById(slot.getBookedByUserId()).ifPresent(student -> {
            String reminderKey = "interview-slot-" + slot.getId() + "-" + tag;
            if (pushLogRepository.existsByUserIdAndReminderKey(student.getId(), reminderKey)) return;

            // 1. Send push if enabled
            if (student.getFcmToken() != null && !student.getFcmToken().isBlank()) {
                fcmService.sendToToken(student.getFcmToken(), title, message, Map.of(
                        "roomCode", slot.getRoomCode() != null ? slot.getRoomCode() : "AXIS-INT-" + slot.getId()
                ));
            }

            // 2. Save in-app notification for student portal
            com.institute.lms.entity.Notification n = new com.institute.lms.entity.Notification();
            n.setUserId(student.getId());
            n.setTitle(title);
            n.setMessage(message);
            n.setType("INTERVIEW_REMINDER");
            n.setActionUrl(slot.getRoomCode() != null ? "/interview/" + slot.getRoomCode() : "/interview/AXIS-INT-" + slot.getId());
            notificationRepository.save(n);

            // 3. Mark in push log to prevent re-triggering
            PushNotificationLog log = new PushNotificationLog();
            log.setUserId(student.getId());
            log.setReminderKey(reminderKey);
            pushLogRepository.save(log);
        });
    }
}

