package com.institute.lms.entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.persistence.*;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.Set;

@Entity
@Table(name = "courses")
@Data
@NoArgsConstructor
@EqualsAndHashCode(callSuper = true, exclude = {"modules", "enrollments", "instructor"})
public class Course extends BaseEntity {
    @Column(nullable = false)
    private String title;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(name = "thumbnail_url")
    private String thumbnailUrl;

    @Column(name = "is_published")
    private Boolean isPublished = false;

    @Column(name = "plan_id")
    private Long planId;

    @ManyToOne
    @JoinColumn(name = "instructor_id")
    @JsonIgnore
    private User instructor;

    @OneToMany(mappedBy = "course", cascade = CascadeType.ALL)
    private Set<Module> modules;

    @OneToMany(mappedBy = "course", cascade = CascadeType.ALL)
    @JsonIgnore
    private Set<Enrollment> enrollments;

    @Transient
    @JsonProperty("totalLessons")
    private Integer totalLessons = 0;

    @Transient
    @JsonProperty("completedLessons")
    private Integer completedLessons = 0;

    @Transient
    @JsonProperty("progress")
    private Double progress = 0.0;

    @Transient
    public Long getInstructorId() {
        return instructor != null ? instructor.getId() : null;
    }

    @Transient
    public String getInstructorName() {
        return instructor != null ? instructor.getName() : null;
    }
}