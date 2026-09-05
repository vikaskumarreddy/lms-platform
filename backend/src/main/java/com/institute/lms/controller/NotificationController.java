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

@RestController
@RequestMapping("/api/notifications")
public class NotificationController {

    private final NotificationRepository notificationRepository;
    private final UserRepository userRepository;
    private final FcmService fcmService;
    private final UserContext userContext;

    public NotificationController(NotificationRepository notificationRepository, UserRepository userRepository,
                                   FcmService fcmService, UserContext userContext) {
        this.notificationRepository = notificationRepository;
        this.userRepository = userRepository;
        this.fcmService = fcmService;
        this.userContext = userContext;
    }

    /** Pushes a notification to a student's device (no-op if push isn't configured/enabled). */
    private void pushToStudent(User student, String title, String message, String actionUrl) {
        if (student.getFcmToken() == null || student.getFcmToken().isBlank()) return;
        Map<String, String> data = actionUrl != null ? Map.of("actionUrl", actionUrl) : Map.of();
        fcmService.sendToToken(student.getFcmToken(), title, message, data);
    }

    @GetMapping
    public List<Notification> getAllNotifications() {
        List<Notification> all = notificationRepository.findAll();
        User current = userContext.currentUser();

        // Students only see notifications targeted at them directly, broadcasts, or their batch/plan
        if (current != null && current.getRole() == User.UserRole.STUDENT) {
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

        // Faculty only see notifications broadcast to everyone, or targeted at their own batch/students.
        if (userContext.isFaculty()) {
            Long batchId = userContext.facultyBatchId();
            Set<Long> batchStudentIds = batchId != null
                    ? userRepository.findByRoleAndBatchId(User.UserRole.STUDENT, batchId)
                            .stream().map(User::getId).collect(Collectors.toSet())
                    : Set.of();
            return all.stream()
                    .filter(n -> "ALL".equals(n.getTargetType())
                            || (batchId != null && "BATCH".equals(n.getTargetType()) && batchId.equals(n.getTargetId()))
                            || (n.getUserId() != null && batchStudentIds.contains(n.getUserId())))
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
        notificationRepository.findById(id).ifPresent(n -> {
            n.setIsRead(true);
            notificationRepository.save(n);
        });
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

    @GetMapping("/unread-count")
    public ResponseEntity<Map<String, Object>> getUnreadCount() {
        User current = userContext.currentUser();
        if (current == null) return ResponseEntity.status(401).build();
        long count = notificationRepository.findByUserIdOrderByCreatedAtDesc(current.getId())
                .stream().filter(n -> !n.getIsRead()).count();
        return ResponseEntity.ok(Map.of("count", count));
    }
}