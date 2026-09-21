package com.institute.lms.repository;

import com.institute.lms.entity.MediaItem;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface MediaItemRepository extends JpaRepository<MediaItem, Long> {
    List<MediaItem> findAllByOrderByCreatedAtDesc();
    List<MediaItem> findAllByMediaTypeOrderByCreatedAtDesc(String mediaType);

    @org.springframework.data.jpa.repository.Query("SELECT COALESCE(SUM(m.storedSize), 0) FROM MediaItem m WHERE m.mediaType = :mediaType")
    long sumStoredSizeByMediaType(@org.springframework.data.repository.query.Param("mediaType") String mediaType);
}
