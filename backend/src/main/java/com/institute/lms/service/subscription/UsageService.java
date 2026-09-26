package com.institute.lms.service.subscription;

import com.institute.lms.entity.Organization;
import com.institute.lms.repository.BranchRepository;
import com.institute.lms.repository.OrganizationRepository;
import com.institute.lms.repository.StudentActivityPeriodRepository;
import com.institute.lms.repository.UserRepository;
import com.institute.lms.subscription.LimitKey;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.format.DateTimeFormatter;
import java.util.EnumMap;
import java.util.Map;
import java.util.Optional;

/**
 * Measures a tenant's current consumption against each {@link LimitKey}.
 *
 * <p>Every count here uses a native, organization-scoped query. That is not incidental:
 * {@code User} and {@code Branch} are tenant-scoped entities, so a derived query such
 * as {@code countByOrganizationIdAndRole} would have Hibernate's tenant discriminator
 * injected on top of the explicit predicate and return 0 whenever the caller is the
 * platform super admin — whose session runs under a sentinel tenant matching no row.
 * A usage service that silently reports zero would report every tenant as well within
 * their limits, which is the worst possible failure mode for enforcement.
 */
@Service
public class UsageService {

    /** Billing month key, e.g. {@code 2026-08}. */
    public static final DateTimeFormatter PERIOD_FORMAT = DateTimeFormatter.ofPattern("yyyy-MM");

    private static final long BYTES_PER_GB = 1024L * 1024L * 1024L;

    private final StudentActivityPeriodRepository activityRepository;
    private final UserRepository userRepository;
    private final BranchRepository branchRepository;
    private final OrganizationRepository organizationRepository;
    private final com.institute.lms.repository.MediaItemRepository mediaItemRepository;
    private final com.institute.lms.repository.PdfDocumentRepository pdfDocumentRepository;
    private final com.institute.lms.repository.PdfNoteRepository pdfNoteRepository;

    private final TrainingHoursSource trainingHoursSource;

    public UsageService(StudentActivityPeriodRepository activityRepository,
                        UserRepository userRepository,
                        BranchRepository branchRepository,
                        OrganizationRepository organizationRepository,
                        com.institute.lms.repository.MediaItemRepository mediaItemRepository,
                        com.institute.lms.repository.PdfDocumentRepository pdfDocumentRepository,
                        com.institute.lms.repository.PdfNoteRepository pdfNoteRepository,
                        Optional<TrainingHoursSource> trainingHoursSource) {
        this.activityRepository = activityRepository;
        this.userRepository = userRepository;
        this.branchRepository = branchRepository;
        this.organizationRepository = organizationRepository;
        this.mediaItemRepository = mediaItemRepository;
        this.pdfDocumentRepository = pdfDocumentRepository;
        this.pdfNoteRepository = pdfNoteRepository;
        // Absent until a training agreement module is present, in which case there are
        // no delivered hours to report and zero is the correct answer.
        this.trainingHoursSource = trainingHoursSource.orElse((orgId, period) -> BigDecimal.ZERO);
    }

    /** The current billing month key. */
    public static String currentPeriod() {
        return YearMonth.now().format(PERIOD_FORMAT);
    }

    public static String periodOf(LocalDate date) {
        return YearMonth.from(date).format(PERIOD_FORMAT);
    }

    /**
     * Students who were active in the current billing month — the billable figure.
     *
     * <p>Counted from the activity ledger, not from student records, so an academy can
     * keep every alumnus on the platform without paying for them. Only a student who
     * logged in, opened content, attended a class, submitted an assessment or applied
     * for a placement this month appears here.
     */
    public long activeStudents(Long organizationId) {
        return activeStudents(organizationId, currentPeriod());
    }

    public long activeStudents(Long organizationId, String periodYm) {
        if (organizationId == null) {
            return 0;
        }
        return activityRepository.countByOrganizationIdAndPeriodYm(organizationId, periodYm);
    }

    /**
     * Total student records held, active or not. Shown alongside the active count so a
     * tenant can see "1,840 on record, 312 active this month" and understand why they
     * are not billed for all of them.
     */
    public long studentRecords(Long organizationId) {
        return organizationId == null ? 0 : userRepository.countStudentRecordsInOrg(organizationId);
    }

    /**
     * Faculty seats in use. Counts instructors and tenant admins, since both are staff
     * logins the plan pays for, and excludes the ghost platform admin we provision into
     * every tenant — charging a customer a seat for our own access account would be
     * indefensible.
     */
    public long facultySeats(Long organizationId) {
        return organizationId == null ? 0 : userRepository.countFacultySeatsInOrg(organizationId);
    }

    public long branches(Long organizationId) {
        return organizationId == null ? 0 : branchRepository.countInOrg(organizationId);
    }

    /** Storage consumed, in bytes. Computed dynamically from all media, files, and PDFs stored for this tenant. */
    public long storageBytes(Long organizationId) {
        if (organizationId == null) {
            return 0;
        }
        long mediaBytes = mediaItemRepository.sumStoredSizeByOrgId(organizationId);
        long pdfDocBytes = pdfDocumentRepository.sumStoredSizeByOrgId(organizationId);
        long pdfNoteBytes = pdfNoteRepository.sumStoredSizeByOrgId(organizationId);
        long totalCalculated = mediaBytes + pdfDocBytes + pdfNoteBytes;

        long orgBytes = organizationRepository.findById(organizationId)
                .map(Organization::getStorageBytesUsed)
                .orElse(0L);

        return Math.max(totalCalculated, orgBytes);
    }

    /** Storage consumed, rounded up to whole GB so a part-used GB counts against the plan. */
    public long storageGb(Long organizationId) {
        long bytes = storageBytes(organizationId);
        return bytes <= 0 ? 0 : (bytes + BYTES_PER_GB - 1) / BYTES_PER_GB;
    }

    /** Storage consumed in GB as double rounded to 2 decimal places, for UI display. */
    public double storageGbDouble(Long organizationId) {
        long bytes = storageBytes(organizationId);
        if (bytes <= 0) return 0.0;
        double gb = bytes / (double) BYTES_PER_GB;
        return Math.round(gb * 100.0) / 100.0;
    }

    /**
     * Trainer hours delivered in the current month, against the plan's included
     * allowance.
     *
     * <p>Sourced from the training worklog, so a Managed Academy tenant's 20 included
     * hours are consumed by evidenced delivery before any purchased hour is drawn down.
     * That ordering is what stops the base fee and the hourly rate billing for the same
     * work.
     */
    public BigDecimal trainingHoursUsed(Long organizationId) {
        return trainingHoursUsed(organizationId, currentPeriod());
    }

    public BigDecimal trainingHoursUsed(Long organizationId, String periodYm) {
        if (organizationId == null) {
            return BigDecimal.ZERO;
        }
        return trainingHoursSource.hoursFor(organizationId, periodYm);
    }

    /**
     * Supplies delivered trainer hours, implemented by the training module.
     *
     * <p>An interface rather than a direct dependency so usage measurement does not
     * have to know about training agreements and worklogs. Spring injects the
     * implementation when one is on the context.
     */
    public interface TrainingHoursSource {
        BigDecimal hoursFor(Long organizationId, String periodYm);
    }

    /** Current consumption for a single limit, in that limit's own unit. */
    public long usageOf(LimitKey key, Long organizationId) {
        if (key == null || organizationId == null) {
            return 0;
        }
        return switch (key) {
            case MAX_ACTIVE_STUDENTS -> activeStudents(organizationId);
            case MAX_FACULTY_ACCOUNTS -> facultySeats(organizationId);
            case MAX_BRANCHES -> branches(organizationId);
            case STORAGE_GB -> storageGb(organizationId);
            case INCLUDED_TRAINING_HOURS -> trainingHoursUsed(organizationId).longValue();
            // An organization always counts as one against a multi-organization
            // allowance. Enterprise groups that genuinely hold several are tracked by
            // the parent agreement rather than from inside a single tenant.
            case MAX_ORGANIZATIONS -> 1L;
        };
    }

    /** Consumption for every limit at once, for the Account page's usage meters. */
    public Map<LimitKey, Long> usageSnapshot(Long organizationId) {
        Map<LimitKey, Long> out = new EnumMap<>(LimitKey.class);
        for (LimitKey key : LimitKey.values()) {
            out.put(key, usageOf(key, organizationId));
        }
        return out;
    }
}
