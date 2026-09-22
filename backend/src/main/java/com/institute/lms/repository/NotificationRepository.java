package com.institute.lms.repository;

import com.institute.lms.entity.Notification;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.transaction.annotation.Transactional;

@Repository
public interface NotificationRepository extends JpaRepository<Notification, Long> {
    List<Notification> findByBroadcastTrue();
    List<Notification> findByUserIdOrderByCreatedAtDesc(Long userId);
    List<Notification> findByTargetTypeAndTargetId(String targetType, Long targetId);

    @Transactional
    @Modifying
    void deleteByCreatedAtBefore(LocalDateTime threshold);
}