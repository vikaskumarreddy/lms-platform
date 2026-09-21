package com.institute.lms.controller;

import com.institute.lms.entity.StudyTopic;
import com.institute.lms.entity.User;
import com.institute.lms.repository.StudyTopicRepository;
import com.institute.lms.util.OrganizationContext;
import com.institute.lms.util.UserContext;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.List;
import java.util.Objects;

@RestController
@RequestMapping("/api/study-topics")
public class StudyTopicController {
    private final StudyTopicRepository repository;
    private final UserContext userContext;

    public StudyTopicController(StudyTopicRepository repository, UserContext userContext) {
        this.repository = repository;
        this.userContext = userContext;
    }

    private boolean isOwnTenant(User user) {
        return user.getOrganizationId() != null && Objects.equals(user.getOrganizationId(),
                OrganizationContext.getCurrentOrgIdStatic());
    }

    @GetMapping
    public ResponseEntity<List<StudyTopic>> list() {
        User user = userContext.currentUser();
        if (user == null) return ResponseEntity.status(401).build();
        if (!isOwnTenant(user)) return ResponseEntity.status(403).build();
        return ResponseEntity.ok(repository.findByUserIdOrderByUpdatedAtDescIdDesc(user.getId()));
    }

    public record CreateTopic(String title) {}

    @PostMapping
    public ResponseEntity<StudyTopic> create(@RequestBody CreateTopic input) {
        User user = userContext.currentUser();
        if (user == null) return ResponseEntity.status(401).build();
        if (!isOwnTenant(user)) return ResponseEntity.status(403).build();
        if (input.title() == null || input.title().isBlank() || input.title().trim().length() > 200)
            return ResponseEntity.badRequest().build();
        StudyTopic topic = new StudyTopic();
        topic.setUserId(user.getId());
        topic.setTitle(input.title().trim());
        return ResponseEntity.ok(repository.save(topic));
    }
}
