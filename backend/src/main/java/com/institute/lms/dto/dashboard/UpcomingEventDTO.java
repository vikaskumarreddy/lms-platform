package com.institute.lms.dto.dashboard;

import lombok.AllArgsConstructor;
import lombok.Data;

@Data
@AllArgsConstructor
public class UpcomingEventDTO {
    private String eventName;
    private String eventType;
    private String date;
}