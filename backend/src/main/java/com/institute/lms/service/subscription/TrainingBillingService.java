package com.institute.lms.service.subscription;

import com.institute.lms.entity.OrgTrainingAgreement;
import com.institute.lms.entity.OrgTrainingWorklog;
import com.institute.lms.exception.BadRequestException;
import com.institute.lms.exception.ErrorCode;
import com.institute.lms.exception.ResourceNotFoundException;
import com.institute.lms.repository.OrgTrainingAgreementRepository;
import com.institute.lms.repository.OrgTrainingWorklogRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;

/**
 * Training agreements, delivered hours, and what is actually billable.
 *
 * <p>Implements {@link UsageService.TrainingHoursSource}, so delivered hours flow into
 * the usage meters without the usage layer needing to know about agreements.
 *
 * <p>The important logic is {@link #billableHours}: hours draw down the plan's included
 * allowance first, and only the excess is chargeable. Managed Academy bundles trainer
 * time in its base fee <em>and</em> the contract meters it hourly — without this
 * ordering, both clauses would charge for the same work, which is the single most
 * likely source of a billing dispute on that plan.
 */
@Service
public class TrainingBillingService implements UsageService.TrainingHoursSource {

    private final OrgTrainingAgreementRepository agreementRepository;
    private final OrgTrainingWorklogRepository worklogRepository;

    public TrainingBillingService(OrgTrainingAgreementRepository agreementRepository,
                                  OrgTrainingWorklogRepository worklogRepository) {
        this.agreementRepository = agreementRepository;
        this.worklogRepository = worklogRepository;
    }

    /** Delivered hours for a month. Called by {@link UsageService}. */
    @Override
    public BigDecimal hoursFor(Long organizationId, String periodYm) {
        if (organizationId == null || periodYm == null) {
            return BigDecimal.ZERO;
        }
        BigDecimal hours = worklogRepository.sumHours(organizationId, periodYm);
        return hours != null ? hours : BigDecimal.ZERO;
    }

    /**
     * How a month's delivered hours split between included and chargeable.
     *
     * @param delivered  total hours logged
     * @param included   hours the plan and any retainer already cover
     * @param chargeable the excess, which is what gets invoiced
     */
    public record HourSplit(BigDecimal delivered, BigDecimal included, BigDecimal chargeable) { }

    /**
     * Splits a month's hours against the allowance.
     *
     * @param includedAllowance the plan's {@code INCLUDED_TRAINING_HOURS} plus any
     *                          retainer hours; hours beyond this become billable
     */
    public HourSplit billableHours(Long organizationId, String periodYm, BigDecimal includedAllowance) {
        BigDecimal delivered = hoursFor(organizationId, periodYm);
        BigDecimal allowance = includedAllowance != null ? includedAllowance : BigDecimal.ZERO;

        BigDecimal consumedFromAllowance = delivered.min(allowance);
        BigDecimal chargeable = delivered.subtract(consumedFromAllowance).max(BigDecimal.ZERO);

        return new HourSplit(delivered, consumedFromAllowance, chargeable);
    }

    public List<OrgTrainingAgreement> forOrganization(Long organizationId) {
        return agreementRepository.findByOrganizationIdOrderByCreatedAtDesc(organizationId);
    }

    public OrgTrainingAgreement require(Long agreementId) {
        return agreementRepository.findById(agreementId)
                .orElseThrow(() -> ResourceNotFoundException.of("Training agreement", agreementId));
    }

    @Transactional
    public OrgTrainingAgreement save(OrgTrainingAgreement agreement) {
        return agreementRepository.save(agreement);
    }

    /**
     * Activates an agreement, refusing while its terms are incomplete.
     *
     * <p>The checks mirror the database constraints, but running them here means the
     * user gets an explanation rather than a constraint violation. Revenue share is the
     * strictest: it cannot go live unless collections run through the platform, because
     * otherwise there is simply nothing to measure the share against.
     */
    @Transactional
    public OrgTrainingAgreement activate(Long agreementId) {
        OrgTrainingAgreement agreement = require(agreementId);

        String blocker = agreement.activationBlocker();
        if (blocker != null) {
            ErrorCode code = OrgTrainingAgreement.MODEL_REVENUE_SHARE.equals(agreement.getBillingModel())
                    && !Boolean.TRUE.equals(agreement.getCollectionsThroughPlatform())
                    ? ErrorCode.REVENUE_SHARE_NOT_VERIFIABLE
                    : ErrorCode.TRAINING_AGREEMENT_INCOMPLETE;
            throw new BadRequestException(code, blocker);
        }

        agreement.setStatus(OrgTrainingAgreement.STATUS_ACTIVE);
        return agreementRepository.save(agreement);
    }

    /** Logs delivered hours against an agreement. */
    @Transactional
    public OrgTrainingWorklog logWork(OrgTrainingWorklog entry) {
        if (entry.getHours() == null || entry.getHours().signum() <= 0) {
            throw BadRequestException.field("hours", "must be greater than zero");
        }
        OrgTrainingAgreement agreement = require(entry.getAgreementId());
        entry.setOrganizationId(agreement.getOrganizationId());

        // Rate is frozen onto the entry at the moment of logging, so a later change to
        // the agreement cannot silently reprice work already delivered.
        if (entry.getRateApplied() == null) {
            entry.setRateApplied(agreement.getRatePerHour());
        }
        return worklogRepository.save(entry);
    }

    public List<OrgTrainingWorklog> worklog(Long organizationId, String periodYm) {
        return worklogRepository.findByOrganizationIdAndPeriodYmOrderByWorkDateDesc(organizationId, periodYm);
    }

    public List<OrgTrainingWorklog> unbilled(Long organizationId, String periodYm) {
        return worklogRepository.findUnbilled(organizationId, periodYm);
    }

    /**
     * What to charge for a month under a per-hour agreement.
     *
     * <p>Returns zero for the other three models: per-student and retainer billing are
     * not driven by the hour log, and revenue share is computed from collections, not
     * from time.
     */
    public BigDecimal chargeableAmount(OrgTrainingAgreement agreement, String periodYm,
                                       BigDecimal includedAllowance) {
        if (!OrgTrainingAgreement.MODEL_PER_FACULTY_HOUR.equals(agreement.getBillingModel())
                || agreement.getRatePerHour() == null) {
            return BigDecimal.ZERO;
        }
        HourSplit split = billableHours(agreement.getOrganizationId(), periodYm, includedAllowance);
        return split.chargeable().multiply(agreement.getRatePerHour()).setScale(2, RoundingMode.HALF_UP);
    }
}
