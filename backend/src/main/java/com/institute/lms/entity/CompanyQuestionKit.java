package com.institute.lms.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.NoArgsConstructor;

/**
 * A "Company Questions" tile — either a full in-app question paper (questions owned
 * separately via {@link AssessmentType#COMPANY_KIT}, this entity only holds the tile
 * metadata) or a pasted PDF URL viewed in the mobile in-app browser.
 *
 * <p>organizationId is inherited from {@link BaseEntity} (@TenantId, stamped on insert).
 */
@Entity
@Table(name = "company_question_kits")
@Data
@EqualsAndHashCode(callSuper = true)
@NoArgsConstructor
public class CompanyQuestionKit extends BaseEntity {

    @Column(name = "company_name", nullable = false)
    private String companyName;

    @Column(name = "logo_url")
    private String logoUrl;

    /** Flat CSV — no tag-management UI planned, so a join table would be overkill. */
    @Column(name = "tags")
    private String tags;

    @Enumerated(EnumType.STRING)
    @Column(name = "mode", nullable = false, length = 20)
    private Mode mode = Mode.CONTENT;

    @Column(name = "pdf_url")
    private String pdfUrl;

    /** PDF source for PDF tiles: {@code URL} (external link) or {@code SELF} (a PdfNote). */
    @Column(name = "pdf_source", nullable = false, length = 10)
    private String pdfSource = "URL";

    /** Id of the self-hosted PdfNote used when pdfSource is SELF. */
    @Column(name = "pdf_note_id")
    private Long pdfNoteId;

    @Column(name = "description", columnDefinition = "TEXT")
    private String description;

    @Column(name = "is_published", nullable = false)
    private Boolean isPublished = true;

    public enum Mode {
        CONTENT,
        PDF
    }
}
