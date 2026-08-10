package com.institute.lms.dto.dashboard;

import lombok.AllArgsConstructor;
import lombok.Data;

import java.math.BigDecimal;
import java.util.List;

@Data
@AllArgsConstructor
public class DashboardStatsDTO {
    private long totalStudents;
    private long activeCourses;
    private BigDecimal totalRevenue;
    private long placedStudents;
    private double placementPercentage;
    private long totalAssignments;
    private long totalExams;
    private long totalEvents;
    private List<RecentEnrollmentDTO> recentEnrollments;
    private List<UpcomingEventDTO> upcomingEvents;
}