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

    /** Video source: {@code URL} (external link, e.g. YouTube) or {@code SELF} (an uploaded MediaItem). */
    @Column(name = "video_source", length = 10)
    private String videoSource = "URL";

    /** Id of the self-hosted MediaItem (video) used when videoSource is SELF. */
    @Column(name = "video_id")
    private Long videoId;

    @Column(name = "thumbnail_url")
    private String thumbnailUrl;

    @Column(name = "pdf_notes_url")
    private String pdfNotesUrl;

    /** PDF source: {@code URL} (external link) or {@code SELF} (a PdfNote). */
    @Column(name = "pdf_source", nullable = false, length = 10)
    private String pdfSource = "URL";

    /** Id of the self-hosted PdfNote used when pdfSource is SELF. */
    @Column(name = "pdf_note_id")
    private Long pdfNoteId;

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
