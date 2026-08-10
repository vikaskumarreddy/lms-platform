package com.institute.lms.dto.dashboard;

import lombok.AllArgsConstructor;
import lombok.Data;

@Data
@AllArgsConstructor
public class RecentEnrollmentDTO {
    private String studentName;
    private String courseName;
    private String date;
    private String status;
}