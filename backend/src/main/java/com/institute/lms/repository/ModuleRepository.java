package com.institute.lms.repository;

import com.institute.lms.entity.Module;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface ModuleRepository extends JpaRepository<Module, Long> {
    @EntityGraph(attributePaths = {"lessons"})
    Optional<Module> findById(Long id);
}
