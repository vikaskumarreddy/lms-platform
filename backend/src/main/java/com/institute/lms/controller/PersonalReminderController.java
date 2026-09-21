package com.institute.lms.controller;

import com.institute.lms.entity.PersonalReminder;
import com.institute.lms.entity.User;
import com.institute.lms.repository.PersonalReminderRepository;
import com.institute.lms.util.OrganizationContext;
import com.institute.lms.util.UserContext;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import java.time.Instant;
import java.time.ZoneId;
import java.util.List;
import java.util.Objects;

@RestController
@RequestMapping("/api/personal-reminders")
public class PersonalReminderController {
    private final PersonalReminderRepository repository;
    private final UserContext users;

    public PersonalReminderController(PersonalReminderRepository repository, UserContext users) {
        this.repository = repository;
        this.users = users;
    }

    private User owner() {
        User user = users.currentUser();
        if (user == null) throw new ResponseStatusException(HttpStatus.UNAUTHORIZED);
        if (user.getOrganizationId() == null || !Objects.equals(user.getOrganizationId(),
                OrganizationContext.getCurrentOrgIdStatic()))
            throw new ResponseStatusException(HttpStatus.FORBIDDEN);
        return user;
    }

    public record CreateReminder(String title, String description, Instant dueAt, String timeZone) {}
    public record ChangeStatus(String status) {}

    @GetMapping
    public List<PersonalReminder> list() {
        return repository.findByUserIdOrderByDueAtAsc(owner().getId());
    }

    @PostMapping
    public PersonalReminder create(@RequestBody CreateReminder input) {
        User user = owner();
        if (input.title() == null || input.title().isBlank() || input.title().trim().length() > 200
                || input.description() != null && input.description().length() > 2000
                || input.dueAt() == null || !input.dueAt().isAfter(Instant.now())
                || input.timeZone() == null || input.timeZone().length() > 80)
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Enter a title and future reminder time");
        try { ZoneId.of(input.timeZone()); }
        catch (java.time.DateTimeException e) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid time zone");
        }
        PersonalReminder reminder = new PersonalReminder();
        reminder.setUserId(user.getId());
        reminder.setTitle(input.title().trim());
        reminder.setDescription(input.description() == null ? "" : input.description().trim());
        reminder.setDueAt(input.dueAt());
        reminder.setTimeZone(input.timeZone());
        return repository.save(reminder);
    }

    @PatchMapping("/{id}/status")
    public PersonalReminder status(@PathVariable Long id, @RequestBody ChangeStatus input) {
        User user = owner();
        if (!"COMPLETED".equals(input.status()) && !"CANCELLED".equals(input.status()))
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid status");
        PersonalReminder reminder = repository.findByIdAndUserId(id, user.getId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND));
        if (!"PENDING".equals(reminder.getStatus()) && !input.status().equals(reminder.getStatus()))
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Reminder is already closed");
        reminder.setStatus(input.status());
        return repository.save(reminder);
    }

    @PutMapping("/{id}")
    public PersonalReminder update(@PathVariable Long id, @RequestBody CreateReminder input) {
        User user = owner();
        if (input.title() == null || input.title().isBlank() || input.title().trim().length() > 200
                || input.description() != null && input.description().length() > 2000
                || input.dueAt() == null
                || input.timeZone() == null || input.timeZone().length() > 80)
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Enter a valid title and reminder time");
        try { ZoneId.of(input.timeZone()); }
        catch (java.time.DateTimeException e) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid time zone");
        }
        PersonalReminder reminder = repository.findByIdAndUserId(id, user.getId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND));
        reminder.setTitle(input.title().trim());
        reminder.setDescription(input.description() == null ? "" : input.description().trim());
        reminder.setDueAt(input.dueAt());
        reminder.setTimeZone(input.timeZone());
        if (input.dueAt().isAfter(Instant.now())) {
            reminder.setStatus("PENDING");
            reminder.setNotificationStatus("PENDING");
        }
        return repository.save(reminder);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        User user = owner();
        PersonalReminder reminder = repository.findByIdAndUserId(id, user.getId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND));
        repository.delete(reminder);
    }
}
