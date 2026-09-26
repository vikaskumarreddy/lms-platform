package com.institute.lms.repository;

import com.institute.lms.entity.PdfDocument;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface PdfDocumentRepository extends JpaRepository<PdfDocument, Long> {

    List<PdfDocument> findAllByOrderByCreatedAtDesc();

    @org.springframework.data.jpa.repository.Query("SELECT COALESCE(SUM(p.storedSize), 0) FROM PdfDocument p")
    long sumStoredSize();

    @org.springframework.data.jpa.repository.Query(value = "SELECT COALESCE(SUM(COALESCE(stored_size, original_size, 0)), 0) FROM pdf_documents WHERE organization_id = :orgId", nativeQuery = true)
    long sumStoredSizeByOrgId(@org.springframework.data.repository.query.Param("orgId") Long orgId);
}
