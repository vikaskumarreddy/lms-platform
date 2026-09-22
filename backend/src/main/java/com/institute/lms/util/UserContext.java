package com.institute.lms.util;

import com.institute.lms.entity.Batch;
import com.institute.lms.entity.User;
import com.institute.lms.repository.BatchRepository;
import com.institute.lms.repository.UserRepository;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;

import java.util.List;

/**
 * Resolves the currently authenticated user from the Spring Security context.
 *
 * <p>The JWT filter sets a {@code org.springframework.security.core.userdetails.User}
 * as the principal (whose username is the account email), so we look the real
 * {@link User} entity back up from the repository. Controllers use this to scope
 * data to a Faculty (INSTRUCTOR) user's own batch.
 */
@Component
public class UserContext {

    private final UserRepository userRepository;
    private final BatchRepository batchRepository;

    public UserContext(UserRepository userRepository, BatchRepository batchRepository) {
        this.userRepository = userRepository;
        this.batchRepository = batchRepository;
    }

    /** The authenticated LMS {@link User}, or {@code null} if none / not resolvable. */
    public User currentUser() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null) return null;

        Object principal = auth.getPrincipal();
        if (principal instanceof User user) {
            return user;
        }
        if (principal instanceof org.springframework.security.core.userdetails.User springUser) {
            // Resolve via a NATIVE (cross-tenant) lookup. The platform super-admin
            // (ADMIN role) is short-circuited by TenantInterceptor.isPlatformSuperAdmin
            // into an empty / "-1" sentinel tenant context, so a discriminator-scoped
            // derived query (findFirstByEmail) would find no row and currentUser() would
            // return null -> isAdmin() false -> every platform endpoint throws
            // "Access denied". findAnyByEmail is native, so it bypasses the @TenantId
            // DISCRIMINATOR predicate. Per-org scoping of the super admin's actual
            // actions is still driven by the JWT organization_id claim / target-org
            // context stamped on writes by the individual endpoints.
            return userRepository.findAnyByEmail(springUser.getUsername()).orElse(null);
        }
        if (principal instanceof String email) {
            return userRepository.findAnyByEmail(email).orElse(null);
        }
        return null;
    }

    /** Whether the current user is Faculty (INSTRUCTOR). */
    public boolean isFaculty() {
        User u = currentUser();
        return u != null && u.getRole() == User.UserRole.INSTRUCTOR;
    }

    /** Whether the current user is Admin. */
    public boolean isAdmin() {
        User u = currentUser();
        return u != null && u.getRole() == User.UserRole.ADMIN;
    }

    /** Whether the current user is a tenant organization admin (INSTITUTE_ADMIN). */
    public boolean isInstituteAdmin() {
        User u = currentUser();
        return u != null && u.getRole() == User.UserRole.INSTITUTE_ADMIN;
    }

    /**
     * Whether the current user administers an organization — either the platform
     * super admin or a tenant's own admin. This is the audience for the Account and
     * billing surface.
     */
    public boolean isAnyAdmin() {
        User u = currentUser();
        return u != null && (u.getRole() == User.UserRole.ADMIN
                || u.getRole() == User.UserRole.INSTITUTE_ADMIN);
    }

    /**
     * Asserts platform super-admin access, throwing a typed 403.
     *
     * <p>Prefer this over {@code throw new RuntimeException("Access denied: ...")},
     * which relies on {@code GlobalExceptionHandler} sniffing the message text to
     * pick a status code.
     */
    public void requireSuperAdmin() {
        if (!isAdmin()) {
            throw com.institute.lms.exception.UnauthorizedException.requiresRole("Super Admin");
        }
    }

    /** Asserts the caller administers an organization (super admin or tenant admin). */
    public void requireOrgAdmin() {
        if (!isAnyAdmin()) {
            throw com.institute.lms.exception.UnauthorizedException.requiresRole("Organization Admin");
        }
    }

    /** Asserts the caller is an org admin or Faculty — the audience for course-content writes. */
    public void requireOrgAdminOrFaculty() {
        if (!isAnyAdmin() && !isFaculty()) {
            throw com.institute.lms.exception.UnauthorizedException.requiresRole("Organization Admin or Faculty");
        }
    }

    /**
     * Asserts the caller either owns {@code targetUserId} or is an org admin — for
     * personal-resource writes (notes, bookmarks) where the id comes from the request
     * body/params rather than the authenticated session.
     */
    public void requireSelfOrAdmin(Long targetUserId) {
        User u = currentUser();
        if (u != null && u.getId().equals(targetUserId)) return;
        if (isAnyAdmin()) return;
        throw com.institute.lms.exception.UnauthorizedException.requiresRole("Account Owner or Organization Admin");
    }


    /**
     * The batch id a Faculty user is scoped to, or {@code null} when the current
     * user is not Faculty (e.g. an admin) or the faculty has no batch assigned.
     *
     * <p>A Faculty (INSTRUCTOR) user may be associated with a batch in two ways:
     * <ol>
     *   <li><b>Direct assignment</b>: the {@code batchId} field on the User entity is set.</li>
     *   <li><b>Mentorship</b>: one or more {@link Batch} records reference this user via
     *       their {@code mentorId} field. This is the typical case for newly created faculty
     *       who are assigned to mentor a batch.</li>
     * </ol>
     * <p>This method checks the direct assignment first, then falls back to
     * querying for batches where the user is the mentor. Active batches are
     * preferred over inactive ones.
     *
     * @return the scoped batch id, or {@code null} if no batch is found
     */
    public Long facultyBatchId() {
        User u = currentUser();
        if (u == null || u.getRole() != User.UserRole.INSTRUCTOR) {
            return null;
        }

        // 1. Check direct batch assignment (admin explicitly assigned the faculty to a batch)
        if (u.getBatchId() != null) {
            return u.getBatchId();
        }

        // 2. Fallback: the faculty is set as a mentor on one or more batches.
        //    This is how newly created faculty typically get their batch association.
        List<Batch> mentoredBatches = batchRepository.findByMentorId(u.getId());
        if (!mentoredBatches.isEmpty()) {
            // Prefer an active batch; fall back to the first mentored batch found.
            return mentoredBatches.stream()
                    .filter(b -> b.getIsActive() != null && b.getIsActive())
                    .findFirst()
                    .map(Batch::getId)
                    .orElse(mentoredBatches.get(0).getId());
        }

        return null;
    }

    /**
     * All batch IDs a Faculty user is associated with (either directly via batchId,
     * or as mentor on one or more batches).
     */
    public List<Long> facultyBatchIds() {
        User u = currentUser();
        if (u == null || u.getRole() != User.UserRole.INSTRUCTOR) {
            return List.of();
        }
        java.util.Set<Long> ids = new java.util.LinkedHashSet<>();
        if (u.getBatchId() != null) {
            ids.add(u.getBatchId());
        }
        List<Batch> mentoredBatches = batchRepository.findByMentorId(u.getId());
        for (Batch b : mentoredBatches) {
            if (b.getId() != null) {
                ids.add(b.getId());
            }
        }
        return new java.util.ArrayList<>(ids);
    }
}
