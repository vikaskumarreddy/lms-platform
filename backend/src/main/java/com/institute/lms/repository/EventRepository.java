package com.institute.lms.repository;

import com.institute.lms.entity.Event;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Repository
public interface EventRepository extends JpaRepository<Event, Long> {
    List<Event> findByBatchId(Long batchId);
    List<Event> findByPlanId(Long planId);
    List<Event> findTop5ByOrderByStartTimeAsc();

    // Events with batchId == null ("All Batches" in the admin portal) must be visible to
    // every student, in addition to events explicitly targeted at the student's batch.
    List<Event> findByBatchIdIsNullOrBatchId(Long batchId);

    // One DAILY_ATTENDANCE event per batch per calendar day, reusing the existing
    // Event/Attendance/mark-attendance machinery instead of a parallel data model.
    Optional<Event> findByBatchIdAndEventTypeAndStartTime(Long batchId, String eventType, LocalDateTime startTime);
}
