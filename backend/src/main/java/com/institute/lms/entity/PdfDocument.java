package com.institute.lms.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.NoArgsConstructor;

/**
 * A PDF document uploaded through the admin portal "PDF Tools" editor.
 * The bytes are stored gzipped on disk under {@code fileName}; this row holds
 * metadata only. organizationId/createdAt are inherited from {@link BaseEntity}.
 */
@Entity
@Table(name = "pdf_documents")
@Data
@EqualsAndHashCode(callSuper = true)
@NoArgsConstructor
public class PdfDocument extends BaseEntity {

    @Column(name = "title", nullable = false)
    private String title;

    /** File name of the gzipped PDF on disk, e.g. {@code doc-123-abc123.pdf.gz}. */
    @Column(name = "file_name")
    private String fileName;

    @Column(name = "page_count")
    private Integer pageCount;

    /** Size of the uploaded PDF in bytes. */
    @Column(name = "original_size")
    private Long originalSize;

    /** Size of the gzipped file stored on disk in bytes. */
    @Column(name = "stored_size")
    private Long storedSize;

    @Column(name = "created_by_user_id")
    private Long createdByUserId;
}
