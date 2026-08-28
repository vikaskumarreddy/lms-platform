package com.institute.lms.dto.placement;

import com.fasterxml.jackson.annotation.JsonFormat;
import lombok.Data;

import java.time.LocalDateTime;

@Data
public class InterviewSlotHistoryDTO {
    private Long id;
    private Long driveId;
    private String companyName;
    private String role;
    private String location;
    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
    private LocalDateTime slotTime;
    private String status;
}
