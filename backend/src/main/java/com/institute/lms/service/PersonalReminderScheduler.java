package com.institute.lms.service;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;

/** Cross-tenant background worker: explicit owner/organization joins replace request tenant context.
 * Database row locks prevent concurrent workers from sending the same reminder.
 * SENT means accepted by FCM, not confirmed displayed by the device.
 */
@Service
public class PersonalReminderScheduler {
    private final JdbcTemplate jdbc;
    private final FcmService fcm;
    public PersonalReminderScheduler(JdbcTemplate jdbc, FcmService fcm) {
        this.jdbc = jdbc;
        this.fcm = fcm;
    }

    public static String message(String description, Instant dueAt, String zone) {
        String when = DateTimeFormatter.ofPattern("EEE, d MMM yyyy • h:mm a XXX")
                .withZone(ZoneId.of(zone)).format(dueAt);
        return "Scheduled: " + when + (description.isBlank() ? "" : "\n" + description)
                + "\nOpen your reminders to mark this complete.";
    }

    @Scheduled(fixedDelay = 15000)
    @Transactional
    public void deliverDue() {
        List<Map<String, Object>> rows = jdbc.queryForList("""
            SELECT r.*, u.fcm_token FROM personal_reminders r
            JOIN users u ON u.id = r.user_id AND u.organization_id = r.organization_id
            WHERE r.status = 'PENDING' AND r.notification_status <> 'SENT'
              AND r.due_at <= CURRENT_TIMESTAMP AND r.attempts < 5
              AND (r.last_attempt_at IS NULL OR r.last_attempt_at < CURRENT_TIMESTAMP - INTERVAL '1 minute')
            ORDER BY r.due_at LIMIT 20 FOR UPDATE OF r SKIP LOCKED
            """);
        for (Map<String, Object> row : rows) {
            long id = ((Number) row.get("id")).longValue();
            int attempts = ((Number) row.get("attempts")).intValue();
            String title = "Reminder: " + row.get("title");
            String body = message((String) row.get("description"),
                    ((Timestamp) row.get("due_at")).toInstant(), (String) row.get("time_zone"));
            if (attempts == 0) {
                jdbc.update("""
                    INSERT INTO notifications (organization_id, user_id, title, message, type,
                        is_read, action_url, target_type, target_id, version)
                    VALUES (?, ?, ?, ?, 'reminder', false, '/notes/0?view=reminders', 'USER', ?, 0)
                    """, row.get("organization_id"), row.get("user_id"), title, body, row.get("user_id"));
            }
            boolean sent = fcm.sendToToken((String) row.get("fcm_token"), title, body,
                    Map.of("type", "reminder", "actionUrl", "/notes/0?view=reminders",
                            "reminderId", Long.toString(id)));
            jdbc.update("""
                UPDATE personal_reminders SET attempts = attempts + 1, last_attempt_at = CURRENT_TIMESTAMP,
                    notification_status = ?, notified_at = ?, updated_at = CURRENT_TIMESTAMP,
                    version = COALESCE(version, 0) + 1 WHERE id = ? AND organization_id = ?
                """, sent ? "SENT" : attempts >= 4 ? "FAILED" : "PENDING",
                    sent ? Timestamp.from(Instant.now()) : null, id, row.get("organization_id"));
        }
    }
}
