package com.institute.lms.repository;

import com.institute.lms.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

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
            @Param("role") String role);

    long countByOrganizationId(Long organizationId);

    // =========================================================================
    // Native queries for platform super-admin org-admin management.
    //
    // The super-admin thread carries the "-1" sentinel tenant in its Hibernate
    // session (see TenantIdentifierResolverImpl), so JPA-derived queries and
    // entity saves are filtered to org "-1" and Hibernate rejects any entity
    // whose @TenantId differs from the session tenant. These native JDBC
    // queries operate directly against SQL, completely bypassing the
    // DISCRIMINATOR multi-tenancy, so the super admin can manage an
    // organizational admin without opening a cross-tenant session.
    // =========================================================================

    /**
     * Native cross-tenant existence check for an email within a specific
     * organization. Bypasses the @TenantId discriminator so the super-admin's
     * "-1" session can read the target org's users table.
     */
    @Query(value =
        "SELECT COUNT(*) > 0 FROM users " +
        "WHERE organization_id = :orgId AND LOWER(email) = LOWER(:email)",
        nativeQuery = true)
    boolean existsAdminEmailInOrg(@Param("orgId") Long orgId, @Param("email") String email);

    // =========================================================================
    // Seat counting for plan-limit enforcement.
    //
    // These MUST be native. Both the platform super admin (sentinel "-1" tenant)
    // and the quota guard need a truthful count for a named organization, and a
    // derived query such as countByOrganizationIdAndRole would have the tenant
    // discriminator injected on top of the explicit organization_id predicate —
    // returning 0 for the super admin and silently reporting that every tenant
    // has used no seats at all.
    //
    // The ghost platform admin (admin@axisora.com, auto-provisioned into every
    // tenant) is excluded throughout: it is our account, not a seat the customer
    // bought, and counting it would quietly consume one of their faculty seats.
    // =========================================================================

    /**
     * Faculty seats consumed in an organization. Counts INSTRUCTOR and
     * INSTITUTE_ADMIN accounts, since both are staff logins the plan pays for,
     * and excludes the ghost platform admin.
     */
    @Query(value =
        "SELECT COUNT(*) FROM users " +
        "WHERE organization_id = :orgId " +
        "  AND role IN ('INSTRUCTOR', 'INSTITUTE_ADMIN') " +
        "  AND (is_ghost IS NULL OR is_ghost = false)",
        nativeQuery = true)
    long countFacultySeatsInOrg(@Param("orgId") Long orgId);

    /** Instructor accounts only, for reporting that distinguishes teachers from admins. */
    @Query(value =
        "SELECT COUNT(*) FROM users " +
        "WHERE organization_id = :orgId AND role = 'INSTRUCTOR' " +
        "  AND (is_ghost IS NULL OR is_ghost = false)",
        nativeQuery = true)
    long countInstructorsInOrg(@Param("orgId") Long orgId);

    /**
     * Total student records held by an organization, active or not.
     *
     * <p>Note this is <em>not</em> the billable figure — billing counts students who
     * were active in the period, from {@code student_activity_period}. This count
     * exists for the storage and fair-use view, and so the Account page can show
     * "1,840 students on record, 312 active this month".
     */
    @Query(value =
        "SELECT COUNT(*) FROM users " +
        "WHERE organization_id = :orgId AND role = 'STUDENT'",
        nativeQuery = true)
    long countStudentRecordsInOrg(@Param("orgId") Long orgId);

    @Query(value =
        "SELECT COUNT(*) FROM users " +
        "WHERE organization_id = :orgId AND role = 'STUDENT' AND is_active = true",
        nativeQuery = true)
    long countActiveStudentRecordsInOrg(@Param("orgId") Long orgId);

    /**
     * Native existence check for an email inside one organization, for any role.
     *
     * <p>This is the correct replacement for {@code existsByEmail} in tenant-facing
     * create paths. Email is unique <em>per organization</em> in the schema
     * ({@code uk_users_org_email}, added in V28), but the JPA field is still annotated
     * {@code unique = true}; using the global check made faculty creation reject an
     * address merely because a different academy already had it.
     */
    @Query(value =
        "SELECT COUNT(*) > 0 FROM users " +
        "WHERE organization_id = :orgId AND LOWER(email) = LOWER(:email)",
        nativeQuery = true)
    boolean existsEmailInOrg(@Param("orgId") Long orgId, @Param("email") String email);

    /**
     * Native INSERT of a new organizational admin for a specific org.
     * Bypasses JPA persistence (which would attempt to validate the entity's
     * @TenantId against the super-admin session's "-1" tenant and fail).
     * Returns the number of rows inserted (1 on success).
     */
    @Modifying
    @Transactional
    @Query(value =
        "INSERT INTO users " +
        "(email, password, name, phone, username, role, is_active, is_email_verified, " +
        " is_ghost, organization_id, created_at, updated_at, version) " +
        "VALUES " +
        "(:email, :password, :name, :phone, NULL, :role, TRUE, FALSE, FALSE, :orgId, NOW(), NOW(), 0)",
        nativeQuery = true)
    int insertOrganizationAdmin(@Param("orgId") Long orgId,
                                 @Param("email") String email,
                                 @Param("password") String password,
                                 @Param("name") String name,
                                 @Param("phone") String phone,
                                 @Param("role") String role);

    /**
     * Native INSERT of the platform ghost super-admin into a tenant.
     *
     * <p>Must be native for the same reason as {@link #insertOrganizationAdmin}, but the
     * failure it avoids is subtler and was previously fatal. Hibernate resolves the
     * tenant identifier when the SESSION opens, not when the entity is saved — and with
     * {@code open-in-view: true} the session is already open, bound to the super admin's
     * "-1" sentinel, before any service code runs. So temporarily setting
     * {@code OrganizationContext} and then calling {@code userRepository.save()} cannot
     * work: the session tenant stays "-1" while the entity carries the real org id, and
     * Hibernate rejects it with "assigned tenant id differs from current tenant id".
     * That made creating an organization fail outright.
     *
     * <p>Differs from {@link #insertOrganizationAdmin} only in setting
     * {@code is_ghost = TRUE}, which hides this account from the tenant's admin list.
     */
    @Modifying
    @Transactional
    @Query(value =
        "INSERT INTO users " +
        "(email, password, name, phone, username, role, is_active, is_email_verified, " +
        " is_ghost, organization_id, created_at, updated_at, version) " +
        "VALUES " +
        "(:email, :password, :name, NULL, NULL, 'ADMIN', TRUE, TRUE, TRUE, :orgId, NOW(), NOW(), 0) " +
        "ON CONFLICT (organization_id, email) DO NOTHING",
        nativeQuery = true)
    int insertGhostAdmin(@Param("orgId") Long orgId,
                         @Param("email") String email,
                         @Param("password") String password,
                         @Param("name") String name);

    /**
     * Native SELECT of the generated id for a newly inserted org admin, found
     * by organization + email. Needed because {@link #insertOrganizationAdmin}
     * cannot combine {@code @Modifying} with a {@code RETURNING} clause reliably
     * across Spring Data JPA versions—we insert first, then read the assigned id.
     */
    @Query(value =
        "SELECT id FROM users " +
        "WHERE organization_id = :orgId AND LOWER(email) = LOWER(:email) " +
        "ORDER BY id DESC LIMIT 1",
        nativeQuery = true)
    Long findOrgAdminIdByEmail(@Param("orgId") Long orgId, @Param("email") String email);

    /**
     * Native SELECT of a single non-ghost org admin (role INSTITUTE_ADMIN) for
     * a specific org, scoped by org id not tenant context. Returns null when no
     * row matches.
     */
    @Query(value =
        "SELECT * FROM users " +
        "WHERE id = :userId AND organization_id = :orgId " +
        "  AND role = 'INSTITUTE_ADMIN' " +
        "  AND (is_ghost IS NULL OR is_ghost = false)",
        nativeQuery = true)
    Optional<User> findOrgAdminById(@Param("orgId") Long orgId, @Param("userId") Long userId);

    /**
     * Native UPDATE for an existing org admin. Only updates the provided
     * columns (null parameters keep the existing value). Bypasses the @TenantId
     * discriminator.
     */
    @Modifying
    @Transactional
    @Query(value =
        "UPDATE users SET " +
        "  name = COALESCE(:name, name), " +
        "  phone = COALESCE(:phone, phone), " +
        "  password = COALESCE(:password, password), " +
        "  is_active = COALESCE(:isActive, is_active), " +
        "  updated_at = NOW(), " +
        "  updated_by = NULL, " +
        "  version = version + 1 " +
        "WHERE id = :userId AND organization_id = :orgId " +
        "  AND role = 'INSTITUTE_ADMIN' " +
        "  AND (is_ghost IS NULL OR is_ghost = false)",
        nativeQuery = true)
    int updateOrganizationAdmin(@Param("orgId") Long orgId,
                                 @Param("userId") Long userId,
                                 @Param("name") String name,
                                 @Param("phone") String phone,
                                 @Param("password") String password,
                                 @Param("isActive") Boolean isActive);

    /**
     * Native DELETE of a non-ghost org admin for a specific org (ignores the
     * @TenantId discriminator).
     */
    @Modifying
    @Transactional
    @Query(value =
        "DELETE FROM users " +
        "WHERE id = :userId AND organization_id = :orgId " +
        "  AND role = 'INSTITUTE_ADMIN' " +
        "  AND (is_ghost IS NULL OR is_ghost = false)",
        nativeQuery = true)
    int deleteOrganizationAdmin(@Param("orgId") Long orgId, @Param("userId") Long userId);
}