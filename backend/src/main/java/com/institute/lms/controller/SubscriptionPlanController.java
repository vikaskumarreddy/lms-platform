package com.institute.lms.controller;

import com.institute.lms.entity.SubscriptionPlan;
import com.institute.lms.repository.SubscriptionPlanRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/subscription-plans")
public class SubscriptionPlanController {

    private final SubscriptionPlanRepository subscriptionPlanRepository;

    public SubscriptionPlanController(SubscriptionPlanRepository subscriptionPlanRepository) {
        this.subscriptionPlanRepository = subscriptionPlanRepository;
    }

    @GetMapping("/admin/all")
    public List<SubscriptionPlan> getAllPlans() {
        return subscriptionPlanRepository.findAll();
    }

    @GetMapping({"", "/active"})
    public List<SubscriptionPlan> getActivePlans(@RequestParam(value = "orgId", required = false) Long orgId) {
        if (orgId != null) {
            return subscriptionPlanRepository.findActiveByOrgIdNative(orgId);
        }
        try {
            List<SubscriptionPlan> plans = subscriptionPlanRepository.findByIsActiveTrue();
            if (plans != null && !plans.isEmpty()) {
                return plans;
            }
        } catch (Exception ignored) {
        }
        return subscriptionPlanRepository.findAllActivePlansNative();
    }

    @PostMapping
    public SubscriptionPlan createPlan(@RequestBody SubscriptionPlan plan) {
        if (plan.getIsActive() == null) plan.setIsActive(true);
        if (plan.getIsPopular() == null) plan.setIsPopular(false);
        return subscriptionPlanRepository.save(plan);
    }

    @PutMapping("/{id}")
    public ResponseEntity<SubscriptionPlan> updatePlan(@PathVariable Long id, @RequestBody SubscriptionPlan plan) {
        return subscriptionPlanRepository.findById(id)
                .map(existing -> {
                    existing.setName(plan.getName());
                    existing.setDescription(plan.getDescription());
                    existing.setPrice(plan.getPrice());
                    existing.setDurationDays(plan.getDurationDays());
                    existing.setIsActive(plan.getIsActive());
                    existing.setFeatures(plan.getFeatures());
                    existing.setColor(plan.getColor());
                    existing.setPeriod(plan.getPeriod());
                    existing.setIsPopular(plan.getIsPopular());
                    return ResponseEntity.ok(subscriptionPlanRepository.save(existing));
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deletePlan(@PathVariable Long id) {
        subscriptionPlanRepository.deleteById(id);
        return ResponseEntity.ok().build();
    }
}