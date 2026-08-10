package com.institute.lms.dto.user;

import com.institute.lms.entity.SubscriptionPlan;
import lombok.AllArgsConstructor;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@AllArgsConstructor
public class StudentResponse {
    private Long id;
    private String name;
    private String email;
    private String phone;
    private String username;
    private String role;
    private Boolean isActive;
    private Boolean isEmailVerified;
    private Long planId;
    private Long batchId;
    private LocalDateTime createdAt;
    private LocalDateTime lastLogin;
    
    // Social links
    private String linkedin;
    private String github;
    
    // Batch details
    private String batchName;
    
    // Subscription plan details
    private String planName;
    private Double planPrice;
    private String planPeriod;
    
    // Placement status
    private Boolean isPlaced;
    private String placedCompany;
    private String placedRole;
    private Double placedPackage;
}
