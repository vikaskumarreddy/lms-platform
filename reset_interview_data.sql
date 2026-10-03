-- 1. Clear all old interview sessions so admin & student see a clean slate
DELETE FROM interview_sessions;

-- 2. Reset all booked slots so students can book fresh
UPDATE interview_slots 
SET status = 'AVAILABLE', 
    booked_by_user_id = NULL, 
    booked_at = NULL, 
    room_code = NULL;

-- 3. Update slot dates to upcoming dates (tomorrow onwards) so they are available to book
UPDATE interview_slots 
SET slot_time = DATE_TRUNC('hour', NOW() + INTERVAL '1 day') + (id * INTERVAL '1 hour')
WHERE slot_time < NOW();

-- 4. Clear interview calendar events & reminders
DELETE FROM events WHERE event_type = 'INTERVIEW';
DELETE FROM notifications WHERE type IN ('INTERVIEW', 'INTERVIEW_REMINDER', 'INTERVIEW_EVALUATION');
