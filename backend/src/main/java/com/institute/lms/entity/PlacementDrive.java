package com.institute.lms.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "placement_drives")
@Data
@NoArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class PlacementDrive extends BaseEntity {
    @Column(name = "company_name", nullable = false)
    private String companyName;

    @Column(nullable = false)
    private String role;

    @Column(name = "package_amount")
    private BigDecimal packageAmount;

    private String location;

    @Column(columnDefinition = "TEXT")
    private String eligibility;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(name = "apply_link")
    private String applyLink;

    private LocalDateTime deadline;

    @Column(name = "is_active")
    private Boolean isActive = true;

    @Column(name = "plan_id")
    private Long planId;
}
