-- FCM device token per user, for push notifications.
ALTER TABLE users ADD COLUMN IF NOT EXISTS fcm_token TEXT;

-- Extra system-config-driven fields for reminder scheduling are read from
-- system_configs (see V19); no schema change needed there.

-- Track which push notifications have already been sent so scheduled jobs
-- (deadline reminders, live-class reminders) don't re-notify the same event.
CREATE TABLE push_notification_log (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    reminder_key VARCHAR(150) NOT NULL,
    sent_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT uq_push_log_user_key UNIQUE (user_id, reminder_key)
);

CREATE INDEX idx_push_log_user ON push_notification_log(user_id);

-- Admin-managed push notification configuration. `firebase.serviceAccountJson`
-- holds the full Firebase service-account JSON (downloaded from Firebase
-- Console > Project Settings > Service Accounts > Generate new private key),
-- which the backend uses to obtain an OAuth2 token for the FCM HTTP v1 API.
-- As soon as this is filled in and `push.enabled` is true, scheduled
-- reminders and admin broadcasts start actually sending push notifications --
-- no redeploy needed.
INSERT INTO system_configs (config_key, config_value, category, description, is_secret) VALUES
    ('firebase.serviceAccountJson', '', 'PUSH_NOTIFICATIONS', 'Firebase service-account JSON (for sending push notifications)', true),
    ('push.enabled', 'false', 'PUSH_NOTIFICATIONS', 'Master switch: enable/disable sending push notifications', false),
    ('push.assignmentReminderHoursBefore', '24', 'PUSH_NOTIFICATIONS', 'Hours before an assignment due date to send a reminder', false),
    ('push.examReminderHoursBefore', '24', 'PUSH_NOTIFICATIONS', 'Hours before an exam date to send a reminder', false),
    ('push.classReminderMinutesBefore', '30', 'PUSH_NOTIFICATIONS', 'Minutes before a live class/event to send a reminder', false)
ON CONFLICT (config_key) DO NOTHING;
