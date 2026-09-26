package com.institute.lms.repository;

import com.institute.lms.entity.PdfNote;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface PdfNoteRepository extends JpaRepository<PdfNote, Long> {
    List<PdfNote> findAllByOrderByCreatedAtDesc();

    @org.springframework.data.jpa.repository.Query(value = "SELECT COALESCE(SUM(COALESCE(stored_size, original_size, 0)), 0) FROM pdf_notes WHERE organization_id = :orgId", nativeQuery = true)
    long sumStoredSizeByOrgId(@org.springframework.data.repository.query.Param("orgId") Long orgId);

    @org.springframework.data.jpa.repository.Query(value = "SELECT COALESCE(SUM(COALESCE(stored_size, original_size, 0)), 0) FROM pdf_notes", nativeQuery = true)
    long sumStoredSize();
}