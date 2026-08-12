package com.institute.lms.controller;

import com.institute.lms.entity.Subscription;
import com.institute.lms.entity.SubscriptionPlan;
import com.institute.lms.entity.User;
import com.institute.lms.repository.SubscriptionPlanRepository;
import com.institute.lms.repository.SubscriptionRepository;
import com.institute.lms.repository.UserRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * Manages a student's subscriptions (a student can be subscribed to multiple
 * plans at once, e.g. "Java Full Stack" + "Placement Pro"). Access-control
 * checks across the app should use the union of all of a student's ACTIVE
 * subscription plan ids, not just the single legacy `users.plan_id` column
 * (which is kept only for backward compatibility / the primary plan badge).
 */
@RestController
@RequestMapping("/api/students/{studentId}/subscriptions")
public class StudentSubscriptionController {

    private final SubscriptionRepository subscriptionRepository;
    private final SubscriptionPlanRepository subscriptionPlanRepository;
    private final UserRepository userRepository;

    public StudentSubscriptionController(SubscriptionRepository subscriptionRepository,
                                          SubscriptionPlanRepository subscriptionPlanRepository,
                                          UserRepository userRepository) {
        this.subscriptionRepository = subscriptionRepository;
        this.subscriptionPlanRepository = subscriptionPlanRepository;
        this.userRepository = userRepository;
    }

    @GetMapping
    public List<Map<String, Object>> getSubscriptions(@PathVariable Long studentId) {
        return subscriptionRepository.findByUserId(studentId).stream()
                .map(this::toMap)
                .collect(Collectors.toList());
    }

    /** All plan ids the student currently has ACTIVE access to. */
    @GetMapping("/active-plan-ids")
    public List<Long> getActivePlanIds(@PathVariable Long studentId) {
        return subscriptionRepository.findByUserIdAndStatus(studentId, "ACTIVE").stream()
                .map(sub -> sub.getPlan() != null ? sub.getPlan().getId() : null)
                .filter(java.util.Objects::nonNull)
                .collect(Collectors.toList());
    }

    @PostMapping
    public ResponseEntity<Map<String, Object>> addSubscription(@PathVariable Long studentId, @RequestBody Map<String, Object> body) {
        User user = userRepository.findById(studentId).orElse(null);
        if (user == null) return ResponseEntity.notFound().build();

        Long planId = body.get("planId") != null ? ((Number) body.get("planId")).longValue() : null;
        SubscriptionPlan plan = planId != null ? subscriptionPlanRepository.findById(planId).orElse(null) : null;
        if (plan == null) return ResponseEntity.badRequest().build();

        Subscription sub = new Subscription();
        sub.setUser(user);
        sub.setPlan(plan);
        sub.setStatus("ACTIVE");
        sub.setStartDate(LocalDateTime.now());
        if (plan.getDurationDays() != null) {
            sub.setEndDate(LocalDateTime.now().plusDays(plan.getDurationDays()));
        }
        Subscription saved = subscriptionRepository.save(sub);

        // Keep the legacy single planId in sync as the "primary" plan so any code
        // still reading users.plan_id (badges, dashboards) keeps working sensibly.
        if (user.getPlanId() == null) {
            user.setPlanId(plan.getId());
            userRepository.save(user);
        }

        return ResponseEntity.ok(toMap(saved));
    }

    @PutMapping("/{subscriptionId}/status")
    public ResponseEntity<Map<String, Object>> updateStatus(@PathVariable Long studentId, @PathVariable Long subscriptionId,
                                                              @RequestBody Map<String, String> body) {
        return subscriptionRepository.findById(subscriptionId)
                .filter(sub -> sub.getUser() != null && sub.getUser().getId().equals(studentId))
                .map(sub -> {
                    sub.setStatus(body.getOrDefault("status", sub.getStatus()));
                    return ResponseEntity.ok(toMap(subscriptionRepository.save(sub)));
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{subscriptionId}")
    public ResponseEntity<Void> removeSubscription(@PathVariable Long studentId, @PathVariable Long subscriptionId) {
        return subscriptionRepository.findById(subscriptionId)
                .filter(sub -> sub.getUser() != null && sub.getUser().getId().equals(studentId))
                .map(sub -> {
                    subscriptionRepository.delete(sub);
                    return ResponseEntity.ok().<Void>build();
                })
                .orElse(ResponseEntity.notFound().build());
    }

    private Map<String, Object> toMap(Subscription sub) {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("id", sub.getId());
        map.put("planId", sub.getPlan() != null ? sub.getPlan().getId() : null);
        map.put("planName", sub.getPlan() != null ? sub.getPlan().getName() : null);
        map.put("status", sub.getStatus());
        map.put("startDate", sub.getStartDate() != null ? sub.getStartDate().toString() : null);
        map.put("endDate", sub.getEndDate() != null ? sub.getEndDate().toString() : null);
        return map;
    }
}
