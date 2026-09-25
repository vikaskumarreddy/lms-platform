package com.institute.lms.entity;

import jakarta.persistence.*;
import lombok.*;

// organizationId is inherited from BaseEntity (@TenantId, stamped on insert).
@Entity
@Table(name = "org_ai_config")
@Data
@EqualsAndHashCode(callSuper = true)
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class OrgAiConfig extends BaseEntity {

    @Column(name = "model_name", nullable = false, length = 50)
    @Builder.Default
    private String modelName = "gemini-3.6-flash";

    @Column(name = "api_key", columnDefinition = "TEXT")
    private String apiKey;

    @Column(name = "enabled")
    @Builder.Default
    private Boolean enabled = true;

    @Column(name = "daily_question_limit")
    @Builder.Default
    private Integer dailyQuestionLimit = 10;

    @Column(name = "daily_challenge_limit")
    @Builder.Default
    private Integer dailyChallengeLimit = 1;

    @Column(name = "lesson_ai_question_limit")
    @Builder.Default
    private Integer lessonAiQuestionLimit = 100;
}
