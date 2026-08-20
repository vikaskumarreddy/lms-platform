package com.institute.lms.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * A student's current placement-eligibility metrics, expressed as percentages.
 * Used together with a PlacementDrive's minimum-criteria thresholds to decide
 * whether the student may apply to that drive.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class PlacementMetricsDTO {
    private double attendancePercentage;
    private double courseCompletionPercentage;
    private double assignmentAveragePercentage;
    private double examAveragePercentage;
}