package com.institute.lms.repository;

import com.institute.lms.entity.PersonalReminder;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;

public interface PersonalReminderRepository extends JpaRepository<PersonalReminder, Long> {
    List<PersonalReminder> findByUserIdOrderByDueAtAsc(Long userId);
    Optional<PersonalReminder> findByIdAndUserId(Long id, Long userId);
}
