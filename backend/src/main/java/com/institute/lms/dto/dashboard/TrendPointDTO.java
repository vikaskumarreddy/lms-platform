package com.institute.lms.dto.dashboard;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

/**
 * One point on a dashboard trend chart: a display label plus the value behind it.
 * Used for the per-month series (study minutes, performance) so the client never
 * has to guess which month an index refers to.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class TrendPointDTO {

    /** Short month label, e.g. "Jan". */
    private String label;

    /** Full period key, e.g. "2026-01". */
    private String period;

    /** Value for that period, in the unit named by {@code unit}. */
    private double value;

    public static List<TrendPointDTO> of(List<TrendPointDTO> points) {
        return points;
    }
}