package com.institute.lms.repository;

import com.institute.lms.entity.PdfNote;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface PdfNoteRepository extends JpaRepository<PdfNote, Long> {
    List<PdfNote> findAllByOrderByCreatedAtDesc();
}