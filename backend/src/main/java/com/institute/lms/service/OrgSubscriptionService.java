package com.institute.lms.service;

import com.institute.lms.entity.OrgSubscription;
import com.institute.lms.repository.OrgSubscriptionRepository;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.util.List;

@Service
public class OrgSubscriptionService {

    private final OrgSubscriptionRepository orgSubscriptionRepository;

    public OrgSubscriptionService(OrgSubscriptionRepository orgSubscriptionRepository) {
        this.orgSubscriptionRepository = orgSubscriptionRepository;
    }

    public List<OrgSubscription> getAll() {
        return orgSubscriptionRepository.findAll();
    }

    public OrgSubscription getById(Long id) {
        return orgSubscriptionRepository.findById(id).orElse(null);
    }

    public OrgSubscription create(String name, String description, BigDecimal price, String period,
                                  String features, Boolean isActive, Boolean isPopular) {
        OrgSubscription sub = new OrgSubscription();
        sub.setName(name);
        sub.setDescription(description);
        sub.setPrice(price);
        sub.setPeriod(period);
        sub.setFeatures(features);
        sub.setIsActive(isActive);
        sub.setIsPopular(isPopular);
        return orgSubscriptionRepository.save(sub);
    }

    public OrgSubscription update(Long id, String name, String description, BigDecimal price, String period,
                                  String features, Boolean isActive, Boolean isPopular) {
        OrgSubscription sub = orgSubscriptionRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Org subscription not found"));
        if (name != null) sub.setName(name);
        if (description != null) sub.setDescription(description);
        if (price != null) sub.setPrice(price);
        if (period != null) sub.setPeriod(period);
        if (features != null) sub.setFeatures(features);
        if (isActive != null) sub.setIsActive(isActive);
        if (isPopular != null) sub.setIsPopular(isPopular);
        return orgSubscriptionRepository.save(sub);
    }

    public void delete(Long id) {
        orgSubscriptionRepository.deleteById(id);
    }
}