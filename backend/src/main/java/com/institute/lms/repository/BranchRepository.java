package com.institute.lms.repository;

import com.institute.lms.entity.Branch;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface BranchRepository extends JpaRepository<Branch, Long> {

    // Derived queries below are automatically scoped to the current tenant by
    // Hibernate's @TenantId discriminator, so they are safe for tenant admins.

    List<Branch> findByIsActiveTrueOrderByIsPrimaryDescNameAsc();

    Optional<Branch> findByIsPrimaryTrue();

    Optional<Branch> findByCode(String code);

    boolean existsByCode(String code);

    /**
     * Branch count for a named organization, as a NATIVE query.
     *
     * <p>Must not be a derived query: {@code Branch} is tenant-scoped, so
     * {@code countByOrganizationId} would have the tenant discriminator injected on
     * top of the explicit predicate and return 0 whenever the caller is the platform
     * super admin (whose session runs under a sentinel tenant matching no row) —
     * silently reporting that no tenant has any branches, and letting the branch
     * limit be exceeded without complaint.
     */
    @Query(value = "SELECT COUNT(*) FROM branches WHERE organization_id = :orgId AND is_active = true",
            nativeQuery = true)
    long countInOrg(@Param("orgId") Long orgId);

    @Query(value = "SELECT * FROM branches WHERE organization_id = :orgId ORDER BY is_primary DESC, name ASC",
            nativeQuery = true)
    List<Branch> findAllInOrg(@Param("orgId") Long orgId);

    @Query(value = "SELECT COUNT(*) > 0 FROM branches "
            + "WHERE organization_id = :orgId AND LOWER(code) = LOWER(:code)",
            nativeQuery = true)
    boolean existsCodeInOrg(@Param("orgId") Long orgId, @Param("code") String code);
}
