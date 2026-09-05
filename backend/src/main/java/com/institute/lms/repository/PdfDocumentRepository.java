package com.institute.lms.repository;

import com.institute.lms.entity.PdfDocument;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface PdfDocumentRepository extends JpaRepository<PdfDocument, Long> {

    List<PdfDocument> findAllByOrderByCreatedAtDesc();
}
