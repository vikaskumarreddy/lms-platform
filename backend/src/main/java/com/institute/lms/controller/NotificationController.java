package com.institute.lms.controller;

import com.institute.lms.entity.Notification;
import com.institute.lms.entity.User;
import com.institute.lms.repository.NotificationRepository;
import com.institute.lms.repository.UserRepository;
import com.institute.lms.service.FcmService;
import com.institute.lms.util.UserContext;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

import java.time.LocalDateTime;
import org.springframework.scheduling.annotation.Scheduled;

@RestController
@RequestMapping("/api/notifications")
public class NotificationController {

    private final NotificationRepository notificationRepository;
    private final UserRepository userRepository;
    private final com.institute.lms.repository.CourseRepository courseRepository;
    private final FcmService fcmService;
    private final UserContext userContext;

    public NotificationController(NotificationRepository notificationRepository,
                                  UserRepository userRepository,
                                  com.institute.lms.repository.CourseRepository courseRepository,
                                  FcmService fcmService,
                                  UserContext userContext) {
        this.notificationRepository = notificationRepository;
        this.userRepository = userRepository;
        this.courseRepository = courseRepository;
        this.fcmService = fcmService;
        this.userContext = userContext;
    }

    /** Hourly background job to delete notifications older than 48 hours. */
    @Scheduled(cron = "0 0 * * * *")
    public void purgeStaleNotifications() {
        try {
            notificationRepository.deleteByCreatedAtBefore(LocalDateTime.now().minusHours(48));
        } catch (Exception e) {
            System.err.println("Failed to purge stale notifications: " + e.getMessage());
        }
    }

    /** Pushes a notification to a student's device (no-op if push isn't configured/enabled). */
    private void pushToStudent(User student, String title, String message, String actionUrl) {
        if (student.getFcmToken() == null || student.getFcmToken().isBlank()) return;
        Map<String, String> data = actionUrl != null ? Map.of("actionUrl", actionUrl) : Map.of();
        fcmService.sendToToken(student.getFcmToken(), title, message, data);
    }

    @GetMapping
    public List<Notification> getAllNotifications() {
        // Enforce 48-hour retention on read
        LocalDateTime cutoff = LocalDateTime.now().minusHours(48);
        try {
            notificationRepository.deleteByCreatedAtBefore(cutoff);
        } catch (Exception ignored) {}

        List<Notification> all = notificationRepository.findAll().stream()
                .filter(n -> n.getCreatedAt() == null || !n.getCreatedAt().isBefore(cutoff))
                .collect(Collectors.toList());

        User current = userContext.currentUser();
        if (current == null) return List.of();

        // Students only see notifications targeted at them directly, broadcasts, or their batch/plan
        if (current.getRole() == User.UserRole.STUDENT) {
            Long studentId = current.getId();
            Long batchId = current.getBatchId();
            Long planId = current.getPlanId();
            return all.stream()
                    .filter(n -> "ALL".equals(n.getTargetType())
                            || (n.getUserId() != null && n.getUserId().equals(studentId))
                            || (batchId != null && "BATCH".equals(n.getTargetType()) && batchId.equals(n.getTargetId()))
                            || (planId != null && "SUBSCRIPTION".equals(n.getTargetType()) && planId.equals(n.getTargetId())))
                    .collect(Collectors.toList());
        }

        // Faculty only see notifications for students belonging to their assigned batches or courses they teach
        if (userContext.isFaculty()) {
            List<Long> batchIds = userContext.facultyBatchIds();
            Set<Long> belongingStudentIds = new java.util.HashSet<>();

            // 1. Students in batches mentored/assigned
            for (Long bId : batchIds) {
                userRepository.findByRoleAndBatchId(User.UserRole.STUDENT, bId)
                        .forEach(u -> belongingStudentIds.add(u.getId()));
            }

            // 2. Students in courses taught by this faculty
            List<com.institute.lms.entity.Course> myCourses = courseRepository.findByInstructorId(current.getId());
            for (com.institute.lms.entity.Course c : myCourses) {
                if (c.getEnrollments() != null) {
                    c.getEnrollments().forEach(e -> {
                        if (e.getUser() != null) belongingStudentIds.add(e.getUser().getId());
                    });
                }
            }

            Set<String> RELEVANT_TYPES = Set.of("chat", "qa", "support", "placement", "exam", "assignment");

            return all.stream()
                    .filter(n -> {
                        String type = n.getType() != null ? n.getType().toLowerCase() : "";
                        if (!RELEVANT_TYPES.contains(type)) return false;

                        boolean isMyBatch = batchIds.contains(n.getTargetId()) && "BATCH".equals(n.getTargetType());
                        boolean isMyStudent = n.getUserId() != null && belongingStudentIds.contains(n.getUserId());
                        boolean isDirectToFaculty = n.getUserId() != null && n.getUserId().equals(current.getId());

                        return isMyBatch || isMyStudent || isDirectToFaculty;
                    })
                    .collect(Collectors.toList());
        }

        // Admins see all notifications
        return all;
    }

    @GetMapping("/broadcasts")
    public List<Notification> getBroadcasts() {
        return notificationRepository.findByBroadcastTrue();
    }

    @GetMapping("/user/{userId}")
    public List<Notification> getUserNotifications(@PathVariable Long userId) {
        return notificationRepository.findByUserIdOrderByCreatedAtDesc(userId);
    }

    @PostMapping
    public ResponseEntity<List<Notification>> sendNotification(@RequestBody Map<String, Object> payload) {
        String title = (String) payload.get("title");
        String message = (String) payload.get("message");
        String type = (String) payload.getOrDefault("type", "info");
        String targetType = (String) payload.getOrDefault("targetType", "ALL");
        Long targetId = payload.get("targetId") != null ? Long.valueOf(payload.get("targetId").toString()) : null;
        String actionUrl = (String) payload.get("actionUrl");
        Boolean broadcast = (Boolean) payload.getOrDefault("broadcast", false);

        @SuppressWarnings("unchecked")
        List<Integer> userIdsRaw = (List<Integer>) payload.get("userIds");
        List<Long> userIds = userIdsRaw != null
                ? userIdsRaw.stream().map(Integer::longValue).collect(Collectors.toList())
                : new ArrayList<>();

        List<Notification> created = new ArrayList<>();

        switch (targetType) {
            case "ALL":
                // Create one broadcast notification + individual notifications for all students
                Notification broadcastNotif = new Notification();
                broadcastNotif.setTitle(title);
                broadcastNotif.setMessage(message);
                broadcastNotif.setType(type);
                broadcastNotif.setTargetType("ALL");
                broadcastNotif.setActionUrl(actionUrl);
                broadcastNotif.setBroadcast(true);
                broadcastNotif.setIsRead(false);
                created.add(notificationRepository.save(broadcastNotif));

                // Also create individual notifications for each student
                List<User> allStudents = userRepository.findByRole(User.UserRole.STUDENT);
                for (User student : allStudents) {
                    Notification n = new Notification();
                    n.setUserId(student.getId());
                    n.setTitle(title);
                    n.setMessage(message);
                    n.setType(type);
                    n.setTargetType("ALL");
                    n.setActionUrl(actionUrl);
                    n.setIsRead(false);
                    created.add(notificationRepository.save(n));
                    pushToStudent(student, title, message, actionUrl);
                }
                break;

            case "SUBSCRIPTION":
                // Send to all students with the specified planId
                if (targetId != null) {
                    List<User> studentsWithPlan = userRepository.findByRoleAndPlanId(User.UserRole.STUDENT, targetId);
                    for (User student : studentsWithPlan) {
                        Notification n = new Notification();
                        n.setUserId(student.getId());
                        n.setTitle(title);
                        n.setMessage(message);
                        n.setType(type);
                        n.setTargetType("SUBSCRIPTION");
                        n.setTargetId(targetId);
                        n.setActionUrl(actionUrl);
                        n.setIsRead(false);
                        created.add(notificationRepository.save(n));
                        pushToStudent(student, title, message, actionUrl);
                    }
                }
                break;

            case "BATCH":
                // Send to all students in the specified batch
                if (targetId != null) {
                    List<User> studentsInBatch = userRepository.findByRoleAndBatchId(User.UserRole.STUDENT, targetId);
                    for (User student : studentsInBatch) {
                        Notification n = new Notification();
                        n.setUserId(student.getId());
                        n.setTitle(title);
                        n.setMessage(message);
                        n.setType(type);
                        n.setTargetType("BATCH");
                        n.setTargetId(targetId);
                        n.setActionUrl(actionUrl);
                        n.setIsRead(false);
                        created.add(notificationRepository.save(n));
                        pushToStudent(student, title, message, actionUrl);
                    }
                }
                break;

            case "USER":
                // Send to specific users
                for (Long uid : userIds) {
                    Notification n = new Notification();
                    n.setUserId(uid);
                    n.setTitle(title);
                    n.setMessage(message);
                    n.setType(type);
                    n.setTargetType("USER");
                    n.setActionUrl(actionUrl);
                    n.setIsRead(false);
                    created.add(notificationRepository.save(n));
                    userRepository.findById(uid).ifPresent(student -> pushToStudent(student, title, message, actionUrl));
                }
                break;

            default:
                break;
        }

        return ResponseEntity.ok(created);
    }

    @PutMapping("/{id}/read")
    public ResponseEntity<Void> markAsRead(@PathVariable Long id) {
        // As requested: mark as read immediately deletes it from database
        try {
            notificationRepository.deleteById(id);
        } catch (Exception ignored) {}
        return ResponseEntity.ok().build();
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteNotification(@PathVariable Long id) {
        notificationRepository.deleteById(id);
        return ResponseEntity.ok().build();
    }

    @DeleteMapping("/clear")
    public ResponseEntity<Void> clearAllNotifications() {
        User current = userContext.currentUser();
        if (current == null) return ResponseEntity.status(401).build();
        List<Notification> userNotifications = notificationRepository.findByUserIdOrderByCreatedAtDesc(current.getId());
        notificationRepository.deleteAll(userNotifications);
        return ResponseEntity.ok().build();
    }

    @PutMapping("/read-all")
    public ResponseEntity<Void> markAllAsRead() {
        // Deletes all visible notifications for this user from database
        List<Notification> visible = getAllNotifications();
        try {
            notificationRepository.deleteAll(visible);
        } catch (Exception ignored) {}
        return ResponseEntity.ok().build();
    }

    @GetMapping("/unread-count")
    public ResponseEntity<Map<String, Object>> getUnreadCount() {
        User current = userContext.currentUser();
        if (current == null) return ResponseEntity.status(401).build();
        long count = getAllNotifications()
                .stream().filter(n -> !Boolean.TRUE.equals(n.getIsRead())).count();
        return ResponseEntity.ok(Map.of("count", count));
    }
}