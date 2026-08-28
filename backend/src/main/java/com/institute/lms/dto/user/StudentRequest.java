package com.institute.lms.dto.user;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class StudentRequest {
    @NotBlank
    private String name;

    @Email
    @NotBlank
    private String email;

    private String password;

    private String phone;

    private String username;

    private Boolean isActive;

    private Long planId;

    private Long batchId;

    private String linkedin;

    private String github;

    private String paymentMethod; // CASH or ONLINE

    private String parentName;

    private String parentPhone;

    private String parentEmail;

    private String notifyMedium; // PUSH, SMS, or WHATSAPP
}
