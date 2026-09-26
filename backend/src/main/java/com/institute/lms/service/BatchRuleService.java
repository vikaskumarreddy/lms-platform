package com.institute.lms.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.institute.lms.entity.Batch;
import com.institute.lms.entity.BatchRule;
import com.institute.lms.repository.BatchRepository;
import com.institute.lms.repository.BatchRuleRepository;
import com.institute.lms.util.OrganizationContext;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;

@Service
@RequiredArgsConstructor
@Slf4j
public class BatchRuleService {

    private final BatchRuleRepository batchRuleRepository;
    private final BatchRepository batchRepository;
    private final OrganizationContext organizationContext;
    private final ObjectMapper objectMapper = new ObjectMapper();

    public List<BatchRule> getAllRules() {
        Long orgId = organizationContext.getCurrentOrgId();
        if (orgId == null) {
            return batchRuleRepository.findAll();
        }
        return batchRuleRepository.findAllByOrgNative(orgId);
    }

    public Optional<BatchRule> getRuleById(Long id) {
        return batchRuleRepository.findById(id);
    }

    @Transactional
    public BatchRule createRule(BatchRule rule) {
        validateRule(rule);
        if (rule.getOrganizationId() == null) {
            rule.setOrganizationId(organizationContext.getCurrentOrgId());
        }
        return batchRuleRepository.save(rule);
    }

    @Transactional
    public BatchRule updateRule(Long id, BatchRule updated) {
        BatchRule existing = batchRuleRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Batch rule not found: " + id));

        validateRule(updated);

        existing.setName(updated.getName());
        existing.setPlanId(updated.getPlanId());
        existing.setBatchId(updated.getBatchId());
        existing.setPriority(updated.getPriority() != null ? updated.getPriority() : 0);
        existing.setIsActive(updated.getIsActive() != null ? updated.getIsActive() : true);
        existing.setConditions(updated.getConditions());

        return batchRuleRepository.save(existing);
    }

    @Transactional
    public void deleteRule(Long id) {
        batchRuleRepository.deleteById(id);
    }

    private void validateRule(BatchRule rule) {
        if (rule.getPlanId() == null) {
            throw new IllegalArgumentException("Subscription Plan is mandatory when creating a batch rule");
        }
        if (rule.getBatchId() == null) {
            throw new IllegalArgumentException("Target Batch is mandatory when creating a batch rule");
        }
        if (rule.getName() == null || rule.getName().isBlank()) {
            throw new IllegalArgumentException("Rule name cannot be blank");
        }

        Batch batch = batchRepository.findById(rule.getBatchId())
                .orElseGet(() -> batchRepository.findAnyById(rule.getBatchId()).orElse(null));

        if (batch == null) {
            throw new IllegalArgumentException("Target batch not found: " + rule.getBatchId());
        }

        if (batch.getPlanId() == null || !batch.getPlanId().equals(rule.getPlanId())) {
            throw new IllegalArgumentException(
                    "Invalid mapping: The target batch must belong to the selected subscription plan (Batch planId: "
                            + batch.getPlanId() + ", Rule planId: " + rule.getPlanId() + ")");
        }
    }

    /**
     * Evaluates active rules for the given org and subscription plan against submitted student data.
     * Returns the matched batchId, or null if no rule conditions match.
     */
    public Long resolveMatchingBatch(Long orgId, Long planId, Map<String, Object> studentData) {
        if (orgId == null || planId == null) {
            return null;
        }

        List<BatchRule> activeRules = batchRuleRepository.findActiveByOrgAndPlanNative(orgId, planId);
        if (activeRules == null || activeRules.isEmpty()) {
            log.debug("No active batch rules found for orgId={}, planId={}", orgId, planId);
            return null;
        }

        log.info("Evaluating {} active batch rules for orgId={}, planId={}", activeRules.size(), orgId, planId);

        for (BatchRule rule : activeRules) {
            if (matchesRule(rule, studentData)) {
                log.info("Student data matched batch rule '{}' (id={}) -> assigning batchId={}",
                        rule.getName(), rule.getId(), rule.getBatchId());
                return rule.getBatchId();
            }
        }

        return null;
    }

    private boolean matchesRule(BatchRule rule, Map<String, Object> studentData) {
        String conditionsJson = rule.getConditions();
        if (conditionsJson == null || conditionsJson.isBlank() || conditionsJson.trim().equals("[]")) {
            // A rule with no specific field conditions acts as a default/catch-all for this plan
            return true;
        }

        try {
            List<Map<String, Object>> conditions = objectMapper.readValue(
                    conditionsJson,
                    new TypeReference<List<Map<String, Object>>>() {}
            );

            if (conditions.isEmpty()) {
                return true;
            }

            for (Map<String, Object> cond : conditions) {
                String fieldKey = (String) cond.get("fieldKey");
                String operator = (String) cond.get("operator");
                Object expectedValObj = cond.get("value");

                if (fieldKey == null || fieldKey.isBlank()) {
                    continue;
                }

                Object actualValObj = studentData != null ? studentData.get(fieldKey) : null;
                if (!evaluateCondition(actualValObj, operator, expectedValObj)) {
                    return false; // All conditions in a rule must match (AND logic)
                }
            }
            return true;
        } catch (Exception e) {
            log.warn("Failed to parse conditions for batch rule id {}: {}", rule.getId(), e.getMessage());
            return false;
        }
    }

    private boolean evaluateCondition(Object actual, String operator, Object expected) {
        String actualStr = actual != null ? actual.toString().trim() : "";
        String expectedStr = expected != null ? expected.toString().trim() : "";
        String op = operator != null ? operator.toUpperCase().trim() : "EQUALS";

        switch (op) {
            case "EQUALS":
                return actualStr.equalsIgnoreCase(expectedStr);

            case "NOT_EQUALS":
                return !actualStr.equalsIgnoreCase(expectedStr);

            case "CONTAINS":
                return actualStr.toLowerCase().contains(expectedStr.toLowerCase());

            case "STARTS_WITH":
                return actualStr.toLowerCase().startsWith(expectedStr.toLowerCase());

            case "ENDS_WITH":
                return actualStr.toLowerCase().endsWith(expectedStr.toLowerCase());

            case "IN":
                // If expected is comma separated values: "Morning,Evening"
                String[] parts = expectedStr.split(",");
                for (String p : parts) {
                    if (actualStr.equalsIgnoreCase(p.trim())) {
                        return true;
                    }
                }
                return false;

            default:
                return actualStr.equalsIgnoreCase(expectedStr);
        }
    }
}
