package com.institute.lms.dto.placement;

import com.fasterxml.jackson.annotation.JsonFormat;
import lombok.Data;

import java.time.LocalDateTime;

/** Interview slot as shown to admins, with the booking student's name resolved (not just their raw id). */
@Data
public class InterviewSlotAdminDTO {
    private Long id;
    private Long driveId;
    private String location;
    private String notes;
    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
    private LocalDateTime slotTime;
    private String status;
    private Long bookedByUserId;
    private String bookedByName;
    private String bookedByEmail;
    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
    private LocalDateTime bookedAt;
}
