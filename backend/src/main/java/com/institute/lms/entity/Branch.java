package com.institute.lms.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.NoArgsConstructor;

/**
 * A branch or campus within an academy.
 *
 * <p>Unlike the billing tables, this <em>is</em> a {@link BaseEntity}: a branch is
 * ordinary academy data that tenant admins read and write, so it takes the standard
 * {@code @TenantId} discriminator and is automatically scoped to the current tenant on
 * every query. Cross-organization branch counts for the platform therefore have to go
 * through native queries — see {@code BranchRepository.countInOrg}.
 *
 * <p>Branches live inside one organization rather than being separate tenants, so a
 * multi-branch academy keeps a single student base, one set of reports and one
 * invoice. Modelling each branch as its own tenant would have fragmented all three.
 */
@Entity
@Table(name = "branches")
@Data
@NoArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class Branch extends BaseEntity {

    @Column(nullable = false, length = 200)
    private String name;

    /** Short code used in listings and reports, e.g. "HYD-01". Unique per tenant. */
    @Column(length = 40)
    private String code;

    @Column(columnDefinition = "TEXT")
    private String address;

    @Column(length = 120)
    private String city;

    @Column(length = 120)
    private String state;

    @Column(length = 10)
    private String pincode;

    @Column(length = 30)
    private String phone;

    @Column
    private String email;

    @Column(name = "contact_person", length = 160)
    private String contactPerson;

    /**
     * The head branch. Created automatically for every organization so a tenant's
     * branch count starts at one — otherwise their first real branch would look like
     * their second against a limit of one.
     */
    @Column(name = "is_primary", nullable = false)
    private Boolean isPrimary = false;

    @Column(name = "is_active", nullable = false)
    private Boolean isActive = true;
}
