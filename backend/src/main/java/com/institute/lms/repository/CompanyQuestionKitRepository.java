package com.institute.lms.repository;

import com.institute.lms.entity.CompanyQuestionKit;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface CompanyQuestionKitRepository extends JpaRepository<CompanyQuestionKit, Long> {

    List<CompanyQuestionKit> findAllByOrderByCompanyNameAsc();

    List<CompanyQuestionKit> findByIsPublishedTrueOrderByCompanyNameAsc();
}
