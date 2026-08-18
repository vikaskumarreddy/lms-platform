package com.institute.lms.repository;

import com.institute.lms.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface UserRepository extends JpaRepository<User, Long> {
    Optional<User> findByEmail(String email);
    boolean existsByEmail(String email);
    boolean existsByPhone(String phone);
    boolean existsByUsername(String username);
    List<User> findByRole(User.UserRole role);
    List<User> findByRoleAndBatchId(User.UserRole role, Long batchId);
    List<User> findByRoleAndPlanId(User.UserRole role, Long planId);
    long countByRole(User.UserRole role);
    
    // Organization-scoped queries
    List<User> findByOrganizationId(Long organizationId);
    List<User> findByOrganizationIdAndRole(Long organizationId, User.UserRole role);
    List<User> findByOrganizationIdAndIsActive(Long organizationId, Boolean isActive);
    Optional<User> findByOrganizationIdAndId(Long organizationId, Long userId);
    Optional<User> findByOrganizationIdAndEmail(Long organizationId, String email);
    boolean existsByOrganizationIdAndEmail(Long organizationId, String email);

    // Legacy fallback useful when no tenant context is resolvable.
    Optional<User> findFirstByEmail(String email);

    /**
     * Cross-tenant credential lookup used ONLY to validate a JWT (its payload already
     * carries the user's organization_id). Runs as a NATIVE query so it is NOT subject
     * to Hibernate's @TenantId DISCRIMINATOR predicate, which would otherwise filter it
     * to the current-thread tenant (`-1`) during the security filter — long before the
     * MVC TenantInterceptor has resolved and set the org context — and thus return no
     * row and prevent authentication.
     */
    @Query(value = "SELECT * FROM users WHERE email = :email ORDER BY id LIMIT 1", nativeQuery = true)
    Optional<User> findAnyByEmail(@Param("email") String email);

         /**
     * Cross-tenant listing of non-ghost administrators for an organization.
     *
     * <p>Used by {@code OrganizationController.listOrgAdmins}, which is reachable
     * by the platform super-admin. The super-admin session has an empty tenant
     * context (TenantInterceptor leaves it null → TenantIdentifierResolverImpl
     * falls back to the "-1" sentinel), so the discriminator-scoped derived query
     * {@code findByOrganizationIdAndRole} returns nothing — every column in the
     * users table, including the discriminator itself, is filtered to org "-1".
     * This NATIVE query bypasses Hibernate's {@code @TenantId} filtering entirely
     * (the same pattern documented for cross-org platform admin views), so the
     * super admin can read an org's administrators regardless of the current
     * thread-local tenant.
     */
    @Query(value =
        "SELECT * FROM users " +
        "WHERE organization_id = :orgId " +
        "  AND role = :role " +
        "  AND (is_ghost IS NULL OR is_ghost = false)",
        nativeQuery = true)
    List<User> findNonGhostAdminsByOrganizationId(
            @Param("orgId") Long orgId,
            @Param("role") User.UserRole role);

    long countByOrganizationId(Long organizationId);
}

