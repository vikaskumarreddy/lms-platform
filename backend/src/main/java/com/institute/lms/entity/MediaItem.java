package com.institute.lms.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.NoArgsConstructor;

/**
 * A video or file (PDF/image) uploaded through the admin portal's
 * "Media &amp; Files" hub. Bytes are stored gzipped on disk under
 * {@code fileName}; this row holds metadata only. Reused by Courses (lesson
 * self-hosted video/PDF) and Company Questions (self-hosted PDF), replacing
 * the old text-to-PDF "Create PDF" generator with real file uploads.
 * organizationId/createdAt are inherited from {@link BaseEntity}.
 */
@Entity
@Table(name = "media_items")
@Data
@EqualsAndHashCode(callSuper = true)
@NoArgsConstructor
public class MediaItem extends BaseEntity {

    public enum MediaType { video, file }

    @Column(name = "title", nullable = false)
    private String title;

    @Column(name = "media_type", nullable = false)
    private String mediaType; // "video" | "file" — kept as String for simple JSON/DB mapping

    @Column(name = "mime_type")
    private String mimeType;

    /** File name of the gzipped media on disk, e.g. {@code media-123-abc123.bin.gz}. */
    @Column(name = "file_name")
    private String fileName;

    /** Size of the original uploaded bytes, before any server-side compression. */
    @Column(name = "original_size")
    private Long originalSize;

    /** Size actually stored on disk (post-compression). Always &lt;= originalSize. */
    @Column(name = "stored_size")
    private Long storedSize;

    @Column(name = "duration_seconds")
    private Integer durationSeconds;

    @Column(name = "width")
    private Integer width;

    @Column(name = "height")
    private Integer height;

    @Column(name = "created_by_user_id")
    private Long createdByUserId;
}
