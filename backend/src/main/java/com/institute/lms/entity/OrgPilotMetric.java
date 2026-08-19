package com.institute.lms.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * One pilot success measure, target against actual.
 *
 * <p>Targets are agreed at the start rather than judged at the end, which is what makes
 * the conversion conversation about evidence instead of impressions. The metrics the
 * platform can measure itself are marked {@link #autoMeasured} and filled in from the
 * activity ledger and placement records; the rest — administrative hours saved, fee
 * collection improvement — only the academy can supply.
 */
@Entity
@Table(name = "org_pilot_metrics")
@Data
@NoArgsConstructor
public class OrgPilotMetric {

    /** Share of imported students who actually became active. Measurable by us. */
    public static final String STUDENT_ACTIVATION = "STUDENT_ACTIVATION";
    public static final String COURSE_COMPLETION = "COURSE_COMPLETION";
    public static final String ASSESSMENT_PARTICIPATION = "ASSESSMENT_PARTICIPATION";
    /** Reported by the academy — we cannot observe their back-office time. */
    public static final String ADMIN_HOURS_SAVED = "ADMIN_HOURS_SAVED";
    /** Reported by the academy unless fee collection runs through the platform. */
    public static final String COLLECTION_IMPROVEMENT = "COLLECTION_IMPROVEMENT";
    public static final String PLACEMENT_APPLICATIONS = "PLACEMENT_APPLICATIONS";
    public static final String MOCK_INTERVIEWS = "MOCK_INTERVIEWS";
    public static final String INTERVIEWS = "INTERVIEWS";
    public static final String SELECTIONS = "SELECTIONS";

    public static final String UNIT_COUNT = "COUNT";
    public static final String UNIT_PERCENT = "PERCENT";
    public static final String UNIT_HOURS = "HOURS";
    public static final String UNIT_CURRENCY = "CURRENCY";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "pilot_id", nullable = false)
    private Long pilotId;

    @Column(name = "metric_key", nullable = false, length = 40)
    private String metricKey;

    @Column(nullable = false, length = 160)
    private String label;

    @Column(nullable = false, length = 20)
    private String unit = UNIT_COUNT;

    @Column(name = "target_value")
    private BigDecimal targetValue;

    @Column(name = "actual_value")
    private BigDecimal actualValue;

    /** True when the platform fills this in itself rather than someone typing it. */
    @Column(name = "auto_measured", nullable = false)
    private Boolean autoMeasured = false;

    @Column(name = "measured_at")
    private LocalDateTime measuredAt;

    @Column(columnDefinition = "TEXT")
    private String notes;

    /** Progress against target as a percentage, or null when either side is unknown. */
    @Transient
    public BigDecimal getAchievementPct() {
        if (targetValue == null || actualValue == null || targetValue.signum() == 0) {
            return null;
        }
        return actualValue.multiply(BigDecimal.valueOf(100))
                .divide(targetValue, 1, java.math.RoundingMode.HALF_UP);
    }

    @Transient
    public boolean isMet() {
        return targetValue != null && actualValue != null
                && actualValue.compareTo(targetValue) >= 0;
    }

    @PrePersist
    @PreUpdate
    public void applyDefaults() {
        if (unit == null) unit = UNIT_COUNT;
        if (autoMeasured == null) autoMeasured = false;
    }
}
