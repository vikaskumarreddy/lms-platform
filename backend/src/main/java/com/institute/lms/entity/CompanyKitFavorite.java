package com.institute.lms.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.NoArgsConstructor;

/**
 * A student's favorite {@link CompanyQuestionKit} — genuinely new per-student state
 * with no existing analog to derive from.
 */
@Entity
@Table(name = "company_kit_favorites")
@Data
@EqualsAndHashCode(callSuper = true)
@NoArgsConstructor
public class CompanyKitFavorite extends BaseEntity {

    @Column(name = "student_id", nullable = false)
    private Long studentId;

    @Column(name = "kit_id", nullable = false)
    private Long kitId;
}
