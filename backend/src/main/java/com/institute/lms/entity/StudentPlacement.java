package com.institute.lms.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Entity
@Table(name = "student_placements")
@Data
@NoArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class StudentPlacement extends BaseEntity {
    
    @ManyToOne
    @JoinColumn(name = "user_id", nullable = false)
    private User user;
    
    @Column(name = "company_name", nullable = false)
    private String companyName;
    
    @Column(nullable = false)
    private String role;
    
    @Column(name = "package_amount")
    private Double packageAmount;
    
    @Column(name = "placed_date")
    private LocalDateTime placedDate;
    
    @Column(columnDefinition = "TEXT")
    private String description;
    
    @Column(name = "is_placed")
    private Boolean isPlaced = false;

    @Column(name = "drive_id")
    private Long driveId;

    /**
     * Application status for this placement drive: OPEN, APPLIED, SHORTLISTED, TECH_ROUND, SELECTED, REJECTED, OFFER_EXTENDED.
     */
    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false)
    private Status status = Status.APPLIED;

    @Column(name = "ats_score")
    private Double atsScore = 0.0;

    @Column(name = "hiring_stage")
    private String hiringStage = "APPLIED";

    @Column(name = "resume_url", length = 1000)
    private String resumeUrl;

    public enum Status {
        OPEN, APPLIED, SHORTLISTED, TECH_ROUND, SELECTED, REJECTED, OFFER_EXTENDED
    }
}