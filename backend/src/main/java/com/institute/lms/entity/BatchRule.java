package com.institute.lms.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "batch_rules")
@Data
@NoArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class BatchRule extends BaseEntity {

    @Column(nullable = false)
    private String name;

    @Column(name = "plan_id", nullable = false)
    private Long planId;

    @Column(name = "batch_id", nullable = false)
    private Long batchId;

    @Column(name = "priority")
    private Integer priority = 0;

    @Column(name = "is_active")
    private Boolean isActive = true;

    /**
     * Stored as JSON array string representing matching conditions.
     * e.g. [{"fieldKey":"collegeName","operator":"EQUALS","value":"MIT"}]
     */
    @Column(columnDefinition = "TEXT")
    private String conditions;
}
