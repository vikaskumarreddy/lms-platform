package com.institute.lms.repository;

import com.institute.lms.entity.InterviewSlot;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface InterviewSlotRepository extends JpaRepository<InterviewSlot, Long> {
    List<InterviewSlot> findByDriveIdOrderBySlotTimeAsc(Long driveId);
    List<InterviewSlot> findByBookedByUserId(Long userId);
    List<InterviewSlot> findByBookedByUserIdIsNotNull();

    /** Used to block a student from holding two slots on the same drive at once. */
    List<InterviewSlot> findByDriveIdAndBookedByUserId(Long driveId, Long userId);
}
