package com.institute.lms.dto.dashboard;

import com.institute.lms.entity.Event;
import lombok.AllArgsConstructor;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * An event as the student dashboard needs it: the full event payload (so the
 * mobile app can parse it with the same model it uses for the calendar) rather
 * than the summary fields the admin rollup uses.
 */
@Data
@AllArgsConstructor
public class StudentUpcomingEventDTO {

    private Long id;
    private String title;
    private String description;
    private String eventType;
    private LocalDateTime startTime;
    private LocalDateTime endTime;
    private String venue;
    private String meetLink;
    private Boolean attendanceRequired;
    private Long batchId;
    private Long planId;

    public static StudentUpcomingEventDTO from(Event e) {
        return new StudentUpcomingEventDTO(
                e.getId(),
                e.getTitle(),
                e.getDescription(),
                e.getEventType(),
                e.getStartTime(),
                e.getEndTime(),
                e.getVenue(),
                e.getMeetLink(),
                e.getAttendanceRequired(),
                e.getBatchId(),
                e.getPlanId());
    }
}