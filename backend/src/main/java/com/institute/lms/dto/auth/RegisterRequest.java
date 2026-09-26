package com.institute.lms.dto.auth;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class RegisterRequest {
    @NotBlank
    private String name;

    @Email
    @NotBlank
    private String email;

    @NotBlank
    private String password;

        private String phone;

    private String role;
    private Long organizationId;
    private Long planId;
    private String paymentMethod;

    private String linkedin;
    private String github;
    private String parentName;
    private String parentPhone;
    private String parentEmail;
    private String notifyMedium;

    private java.util.Map<String, Object> customFields;
}

