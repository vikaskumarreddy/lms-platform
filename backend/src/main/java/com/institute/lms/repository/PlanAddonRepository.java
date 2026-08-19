package com.institute.lms.repository;

import com.institute.lms.entity.PlanAddon;
import com.institute.lms.subscription.AddonCategory;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

/** Platform add-on catalog. Not tenant-scoped — see {@link OrgSubscriptionRepository}. */
@Repository
public interface PlanAddonRepository extends JpaRepository<PlanAddon, Long> {

    Optional<PlanAddon> findByCode(String code);

    boolean existsByCode(String code);

    List<PlanAddon> findByIsActiveTrueOrderByDisplayOrderAsc();

    List<PlanAddon> findAllByOrderByDisplayOrderAsc();

    List<PlanAddon> findByCategoryAndIsActiveTrueOrderByDisplayOrderAsc(AddonCategory category);

    /**
     * Add-ons that raise a given limit, e.g. {@code MAX_ACTIVE_STUDENTS}. Lets a
     * quota error point at the add-on that would resolve it without hard-coding
     * add-on codes into the enforcement path.
     */
    List<PlanAddon> findByIncrementsLimitKeyAndIsActiveTrue(String incrementsLimitKey);

    /** Add-ons that grant a given entitlement, used the same way for feature blocks. */
    List<PlanAddon> findByGrantsEntitlementKeyAndIsActiveTrue(String grantsEntitlementKey);
}
