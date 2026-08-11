package com.institute.lms.repository;

import com.institute.lms.entity.Attendance;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface AttendanceRepository extends JpaRepository<Attendance, Long> {
    List<Attendance> findByEventId(Long eventId);
    List<Attendance> findByUserId(Long userId);
    Optional<Attendance> findByUserIdAndEventId(Long userId, Long eventId);
    long countByUserId(Long userId);
    long countByUserIdAndPresentTrue(Long userId);
}

