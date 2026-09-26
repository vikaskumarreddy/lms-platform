package com.institute.lms.controller;

import com.institute.lms.entity.BatchRule;
import com.institute.lms.service.BatchRuleService;
import com.institute.lms.util.UserContext;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/batch-rules")
@RequiredArgsConstructor
public class BatchRuleController {

    private final BatchRuleService batchRuleService;
    private final UserContext userContext;

    @GetMapping
    public List<BatchRule> getAllRules() {
        return batchRuleService.getAllRules();
    }

    @GetMapping("/{id}")
    public ResponseEntity<BatchRule> getRuleById(@PathVariable Long id) {
        return batchRuleService.getRuleById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping
    public ResponseEntity<?> createRule(@RequestBody BatchRule rule) {
        userContext.requireOrgAdmin();
        try {
            BatchRule created = batchRuleService.createRule(rule);
            return ResponseEntity.ok(created);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(java.util.Map.of("message", e.getMessage()));
        }
    }

    @PutMapping("/{id}")
    public ResponseEntity<?> updateRule(@PathVariable Long id, @RequestBody BatchRule rule) {
        userContext.requireOrgAdmin();
        try {
            BatchRule updated = batchRuleService.updateRule(id, rule);
            return ResponseEntity.ok(updated);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(java.util.Map.of("message", e.getMessage()));
        }
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteRule(@PathVariable Long id) {
        userContext.requireOrgAdmin();
        batchRuleService.deleteRule(id);
        return ResponseEntity.ok().build();
    }
}
