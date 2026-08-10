package com.institute.lms.entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.NoArgsConstructor;
import java.util.Set;

@Entity
@Table(name = "lessons")
@Data
@NoArgsConstructor
@EqualsAndHashCode(callSuper = true, exclude = {"module", "progress", "bookmarks"})
public class Lesson extends BaseEntity {
    @Column(nullable = false)
    private String title;

    @Column(name = "heading")
    private String heading;

    @Column(columnDefinition = "TEXT")
    private String content;

    @Column(name = "video_url")
    private String videoUrl;

    @Column(name = "thumbnail_url")
    private String thumbnailUrl;

    @Column(name = "pdf_notes_url")
    private String pdfNotesUrl;

    @Column(name = "order_index")
    private Integer orderIndex;

    @Column(name = "duration_minutes")
    private Integer durationMinutes;

    @Column(name = "is_locked")
    private Boolean isLocked = false;

    @Column(name = "is_mandatory")
    private Boolean isMandatory = true;

    @ManyToOne
    @JoinColumn(name = "module_id", nullable = false)
    @JsonIgnore
    private Module module;

    @OneToMany(mappedBy = "lesson", cascade = CascadeType.ALL)
    @JsonIgnore
    private Set<Progress> progress;

    @OneToMany(mappedBy = "lesson", cascade = CascadeType.ALL)
    @JsonIgnore
    private Set<Bookmark> bookmarks;
}
