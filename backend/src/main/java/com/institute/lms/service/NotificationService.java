package com.institute.lms.service;

import com.institute.lms.entity.Notification;
import com.institute.lms.entity.OrgFeatureSettings;
import com.institute.lms.entity.User;
import com.institute.lms.repository.NotificationRepository;
import com.institute.lms.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.Collection;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.function.Function;

/**
 * One place to answer "who should hear about this, and how do we tell them".
 *
 * <p>Content the admin publishes (an assignment, an exam, a placement drive, a
 * calendar event, a certificate) already knows its own audience: assignments and
 * exams carry {@code batchIds}, drives carry a {@code planId}, events carry both,
 * a certificate belongs to one student. This service turns any of those into a
 * concrete student list, writes an in-app {@link Notification} row per student,
 * and fires a push to whichever of them have a device token.
 *
 * <p>Two deliberate properties:
 * <ul>
 *   <li><b>Never breaks the write it follows.</b> Every entry point swallows its own
 *       failures. Publishing an exam must not 500 because Firebase is misconfigured
 *       or a token has expired - the exam is the user's work, the notification is a
 *       side effect.</li>
 *   <li><b>Runs in its own transaction.</b> {@code REQUIRES_NEW} keeps notification
 *       rows from being rolled back with (or rolling back) the caller's entity save.</li>
 * </ul>
 */
@Service
public class NotificationService {

    private final NotificationRepository notificationRepository;
    private final UserRepository userRepository;
    private final FcmService fcmService;
    private final OrgFeatureSettingsService featureSettingsService;

    // Maps the free-text "type" slug each caller already passes (assignment,
    // exam, placement, event, certificate, grading, attendance) onto the
    // matching org-level on/off switch, so admins can silence a category
    // without every call site needing its own check.
    private static final Map<String, Function<OrgFeatureSettings, Boolean>> TOGGLE_BY_TYPE = Map.of(
            "assignment", OrgFeatureSettings::getNotifyAssignments,
            "exam", OrgFeatureSettings::getNotifyExams,
            "placement", OrgFeatureSettings::getNotifyPlacements,
            "event", OrgFeatureSettings::getNotifyClasses,
            "certificate", OrgFeatureSettings::getNotifyCertificates,
            "grading", OrgFeatureSettings::getNotifyGrading,
            "attendance", OrgFeatureSettings::getAttendanceNotificationsEnabled
    );

    public NotificationService(NotificationRepository notificationRepository,
                               UserRepository userRepository,
                               FcmService fcmService,
                               OrgFeatureSettingsService featureSettingsService) {
        this.notificationRepository = notificationRepository;
        this.userRepository = userRepository;
        this.fcmService = fcmService;
        this.featureSettingsService = featureSettingsService;
    }

    /** True unless the audience's org has explicitly turned this notification category off. */
    private boolean isCategoryEnabled(List<User> audience, String type) {
        Function<OrgFeatureSettings, Boolean> toggle = type != null ? TOGGLE_BY_TYPE.get(type) : null;
        if (toggle == null) return true;
        Long organizationId = audience.stream()
                .filter(Objects::nonNull)
                .map(User::getOrganizationId)
                .filter(Objects::nonNull)
                .findFirst()
                .orElse(null);
        if (organizationId == null) return true;
        Boolean enabled = toggle.apply(featureSettingsService.getEffective(organizationId));
        return enabled == null || enabled;
    }

    /**
     * Students in any of the given batches. An empty or null list means the content
     * was published to "All Batches", so every student in the tenant is eligible -
     * mirroring how AssignmentController already decides visibility.
     */
    public List<User> audienceForBatches(Collection<Long> batchIds) {
        if (batchIds == null || batchIds.isEmpty()) {
            return userRepository.findByRole(User.UserRole.STUDENT);
        }
        // De-duplicated by id: a student sits in one batch, but overlapping batch
        // lists would otherwise notify them twice for the same item.
        Map<Long, User> unique = new LinkedHashMap<>();
        for (Long batchId : batchIds) {
            if (batchId == null) continue;
            for (User student : userRepository.findByRoleAndBatchId(User.UserRole.STUDENT, batchId)) {
                unique.put(student.getId(), student);
            }
        }
        return new ArrayList<>(unique.values());
    }

    /** Students on a given subscription plan; null plan means everyone. */
    public List<User> audienceForPlan(Long planId) {
        if (planId == null) {
            return userRepository.findByRole(User.UserRole.STUDENT);
        }
        return userRepository.findByRoleAndPlanId(User.UserRole.STUDENT, planId);
    }

    /**
     * Students matching a batch <em>and</em> a plan, as calendar events allow. When
     * both are set the audience is the intersection: an event aimed at "Batch A" and
     * "Premium" means premium students in batch A, not the union of the two groups.
     */
    public List<User> audienceForBatchAndPlan(Long batchId, Long planId) {
        if (batchId == null && planId == null) {
            return userRepository.findByRole(User.UserRole.STUDENT);
        }
        if (batchId == null) return audienceForPlan(planId);
        if (planId == null) return audienceForBatches(List.of(batchId));

        Set<Long> planStudentIds = new LinkedHashSet<>();
        for (User u : userRepository.findByRoleAndPlanId(User.UserRole.STUDENT, planId)) {
            planStudentIds.add(u.getId());
        }
        List<User> result = new ArrayList<>();
        for (User u : userRepository.findByRoleAndBatchId(User.UserRole.STUDENT, batchId)) {
            if (planStudentIds.contains(u.getId())) result.add(u);
        }
        return result;
    }

    /**
     * Records and delivers a notification to every student in {@code audience}.
     *
     * @param type      short slug the app uses to pick an icon and a destination
     *                  (e.g. "assignment", "exam", "placement", "event", "certificate")
     * @param actionUrl in-app route to open on tap, e.g. "/assignments"
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public int notifyStudents(List<User> audience, String title, String message,
                              String type, String actionUrl,
                              String targetType, Long targetId) {
        if (audience == null || audience.isEmpty()) return 0;
        if (!isCategoryEnabled(audience, type)) return 0;

        List<String> tokens = new ArrayList<>();
        int saved = 0;

        for (User student : audience) {
            if (student == null || student.getId() == null) continue;
            try {
                Notification n = new Notification();
                n.setUserId(student.getId());
                n.setTitle(title);
                n.setMessage(message);
                n.setType(type);
                n.setActionUrl(actionUrl);
                n.setTargetType(targetType != null ? targetType : "USER");
                n.setTargetId(targetId);
                n.setIsRead(false);
                // Inherited from BaseEntity; set explicitly because the audience was
                // resolved for a specific tenant and the @PrePersist stamp reads a
                // thread-local that a background caller may not have.
                n.setOrganizationId(student.getOrganizationId());
                notificationRepository.save(n);
                saved++;
            } catch (Exception e) {
                System.err.println("Failed to record notification for user "
                        + student.getId() + ": " + e.getMessage());
            }

            String token = student.getFcmToken();
            if (token != null && !token.isBlank()) tokens.add(token);
        }

        // Data payload lets the app deep-link straight to the item instead of
        // dumping the student on a generic list screen.
        Map<String, String> data = new LinkedHashMap<>();
        data.put("type", type != null ? type : "info");
        if (actionUrl != null) data.put("actionUrl", actionUrl);
        if (targetId != null) data.put("targetId", String.valueOf(targetId));
        data.put("click_action", "FLUTTER_NOTIFICATION_CLICK");

        try {
            fcmService.sendToTokens(tokens, title, message, data);
        } catch (Exception e) {
            System.err.println("Push delivery failed for '" + title + "': " + e.getMessage());
        }

        return saved;
    }

    /**
     * Fire-and-forget wrapper for use straight after a create/update. Catches
     * everything: a notification problem must never fail the publish that triggered it.
     */
    public void safeNotify(List<User> audience, String title, String message,
                           String type, String actionUrl, String targetType, Long targetId) {
        try {
            int count = notifyStudents(audience, title, message, type, actionUrl, targetType, targetId);
            System.out.println("Notified " + count + " student(s): " + title);
        } catch (Exception e) {
            System.err.println("Notification dispatch failed for '" + title + "': " + e.getMessage());
        }
    }

    /** Single-student convenience, used by per-student content such as certificates. */
    public void safeNotifyUser(Long userId, String title, String message,
                               String type, String actionUrl) {
        if (userId == null) return;
        userRepository.findById(userId).ifPresent(user ->
                safeNotify(List.of(user), title, message, type, actionUrl, "USER", userId));
    }
}
