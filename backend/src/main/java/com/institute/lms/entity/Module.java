package com.institute.lms.entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.NoArgsConstructor;
import java.util.Set;

@Entity
@Table(name = "modules")
@Data
@NoArgsConstructor
@EqualsAndHashCode(callSuper = true, exclude = {"lessons", "course"})
public class Module extends BaseEntity {
    @Column(nullable = false)
    private String title;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(name = "order_index")
    private Integer orderIndex;

    @Column(name = "icon")
    private String icon;

    @Column(name = "color")
    private String color;

    @Column(name = "is_locked")
    private Boolean isLocked = false;

    @ManyToOne
    @JoinColumn(name = "course_id", nullable = false)
    @JsonIgnore
    private Course course;

    @OneToMany(mappedBy = "module", cascade = CascadeType.ALL)
    private Set<Lesson> lessons;

    /**
     * Number of lessons in this module.
     */
    @Transient
    public int getTotalLessons() {
        return lessons != null ? lessons.size() : 0;
    }
}
