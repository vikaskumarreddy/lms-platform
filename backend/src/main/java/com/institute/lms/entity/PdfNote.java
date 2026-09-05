package com.institute.lms.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.NoArgsConstructor;

/**
 * A faculty-authored PDF note (the "Create PDF" feature). {@code content} keeps
 * the human-editable source text, while the rendered PDF itself is stored on
 * disk (gzipped) via {@code fileName} and served through
 * {@code /api/pdf-notes/{id}/file}. organizationId is inherited from
 * {@link BaseEntity} ({@code @TenantId}, stamped on insert).
 */
@Entity
@Table(name = "pdf_notes")
@Data
@EqualsAndHashCode(callSuper = true)
@NoArgsConstructor
public class PdfNote extends BaseEntity {

    @Column(name = "title", nullable = false)
    private String title;

    @Column(name = "content", columnDefinition = "TEXT", nullable = false)
    private String content;

    /** The LMS user (faculty/admin) who authored this note. */
    @Column(name = "created_by_user_id")
    private Long createdByUserId;

    /** File name of the gzipped PDF on disk, e.g. {@code pdf-123-abc123.pdf.gz}. */
    @Column(name = "file_name")
    private String fileName;

    /** Size of the uncompressed rendered PDF in bytes. */
    @Column(name = "original_size")
    private Long originalSize;

    /** Size of the gzipped file stored on disk in bytes. Always &lt;= originalSize. */
    @Column(name = "stored_size")
    private Long storedSize;
}