package com.institute.lms.repository;

import com.institute.lms.entity.Course;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface CourseRepository extends JpaRepository<Course, Long> {
    @EntityGraph(attributePaths = {"modules", "modules.lessons", "enrollments"})
    List<Course> findAll();

    @EntityGraph(attributePaths = {"modules", "modules.lessons", "enrollments"})
    Optional<Course> findById(Long id);
    
    @Query("SELECT c FROM Course c WHERE c.instructor.id = :instructorId")
    List<Course> findByInstructorId(@Param("instructorId") Long instructorId);

    long countByIsPublishedTrue();
}
