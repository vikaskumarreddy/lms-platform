package com.institute.lms.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.NoArgsConstructor;

/**
 * Admin-configurable key/value system setting (Firebase, Razorpay, JWT, etc.).
 * Lets the admin portal manage credentials/config that used to be hardcoded
 * env-style values, without redeploying the backend or mobile app.
 */
@Entity
@Table(name = "system_configs")
@Data
@NoArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class SystemConfig extends GlobalEntity {

    @Column(name = "config_key", nullable = false, unique = true)
    private String configKey;

    @Column(name = "config_value", columnDefinition = "TEXT")
    private String configValue;

    @Column(name = "category", nullable = false)
    private String category = "GENERAL";

    @Column(name = "description")
    private String description;

    @Column(name = "is_secret")
    private Boolean isSecret = false;
}
