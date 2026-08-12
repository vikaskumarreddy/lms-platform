package com.institute.lms.repository;

import com.institute.lms.entity.PushNotificationLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface PushNotificationLogRepository extends JpaRepository<PushNotificationLog, Long> {
    boolean existsByUserIdAndReminderKey(Long userId, String reminderKey);
}
