package com.institute.lms.controller;

import com.institute.lms.entity.Subscription;
import com.institute.lms.repository.SubscriptionRepository;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/subscriptions")
public class SubscriptionController {

    private final SubscriptionRepository subscriptionRepository;

    public SubscriptionController(SubscriptionRepository subscriptionRepository) {
        this.subscriptionRepository = subscriptionRepository;
    }

    @GetMapping
    public List<Map<String, Object>> getAllSubscriptions() {
        return subscriptionRepository.findAll().stream()
                .map(sub -> Map.<String, Object>of(
                        "id", sub.getId(),
                        "user", Map.of(
                                "id", sub.getUser() != null ? sub.getUser().getId() : null,
                                "fullName", sub.getUser() != null ? sub.getUser().getName() : null,
                                "email", sub.getUser() != null ? sub.getUser().getEmail() : null
                        ),
                        "plan", Map.of(
                                "id", sub.getPlan() != null ? sub.getPlan().getId() : null,
                                "name", sub.getPlan() != null ? sub.getPlan().getName() : null
                        ),
                        "status", sub.getStatus(),
                        "startDate", sub.getStartDate() != null ? sub.getStartDate().toString() : null,
                        "endDate", sub.getEndDate() != null ? sub.getEndDate().toString() : null
                ))
                .collect(Collectors.toList());
    }
}