package com.institute.lms.repository;

import com.institute.lms.entity.CompanyKitFavorite;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface CompanyKitFavoriteRepository extends JpaRepository<CompanyKitFavorite, Long> {

    List<CompanyKitFavorite> findByStudentId(Long studentId);

    Optional<CompanyKitFavorite> findByStudentIdAndKitId(Long studentId, Long kitId);

    void deleteByStudentIdAndKitId(Long studentId, Long kitId);

    void deleteByKitId(Long kitId);
}
