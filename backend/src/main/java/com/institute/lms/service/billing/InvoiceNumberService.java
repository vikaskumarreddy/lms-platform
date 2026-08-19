package com.institute.lms.service.billing;

import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;

/**
 * Issues gapless, per-financial-year document numbers such as
 * {@code AX/2026-27/00001}.
 *
 * <p><strong>Why not a database sequence.</strong> Sequences are deliberately
 * non-transactional: a rolled-back transaction keeps its consumed value, leaving a
 * hole in the series. For an internal id that is a feature; for a statutory invoice
 * series it is a defect, because the numbering has to be continuous and explicable.
 * So allocation goes through a counter row locked with {@code SELECT ... FOR UPDATE} —
 * concurrent callers serialise on that row, and if the caller rolls back, the number
 * is released with it.
 *
 * <p>The Indian financial year runs April to March, so April 2026 through March 2027
 * are all {@code 2026-27}. Deriving that from the calendar year alone would restart
 * the series in the middle of the year.
 */
@Service
public class InvoiceNumberService {

    public static final String DOC_INVOICE = "INVOICE";
    public static final String DOC_CREDIT_NOTE = "CREDIT_NOTE";

    /** The Indian financial year starts in April. */
    private static final int FY_START_MONTH = 4;

    @PersistenceContext
    private EntityManager entityManager;

    /** The financial year a date falls in, as {@code 2026-27}. */
    public String financialYearOf(LocalDate date) {
        LocalDate d = date != null ? date : LocalDate.now();
        int startYear = d.getMonthValue() >= FY_START_MONTH ? d.getYear() : d.getYear() - 1;
        return String.format("%d-%02d", startYear, (startYear + 1) % 100);
    }

    public String currentFinancialYear() {
        return financialYearOf(LocalDate.now());
    }

    /**
     * Allocates the next number in the series.
     *
     * <p>Joins the caller's transaction ({@code MANDATORY}) rather than starting its
     * own. That is the point: the number must be committed or discarded together with
     * the invoice it belongs to. Allocating in a separate transaction would burn a
     * number whenever invoice creation subsequently failed — reintroducing exactly the
     * gaps the counter table exists to prevent.
     *
     * @param docType {@link #DOC_INVOICE} or {@link #DOC_CREDIT_NOTE}
     * @param prefix  organisation prefix, e.g. {@code AX}
     */
    @Transactional(propagation = Propagation.MANDATORY)
    public String allocate(String docType, String prefix, LocalDate date) {
        String financialYear = financialYearOf(date);
        String resolvedPrefix = prefix != null && !prefix.isBlank() ? prefix.trim() : "AX";

        // Create the counter for this (docType, FY) if it is the first document of the
        // year. ON CONFLICT DO NOTHING makes concurrent first-issues safe.
        entityManager.createNativeQuery("""
                INSERT INTO org_document_sequences (doc_type, financial_year, last_number, prefix, updated_at)
                VALUES (:docType, :fy, 0, :prefix, NOW())
                ON CONFLICT (doc_type, financial_year) DO NOTHING
                """)
                .setParameter("docType", docType)
                .setParameter("fy", financialYear)
                .setParameter("prefix", resolvedPrefix)
                .executeUpdate();

        // Lock the counter row. Any concurrent allocation for the same series waits
        // here, so two invoices can never take the same number.
        entityManager.createNativeQuery("""
                SELECT last_number FROM org_document_sequences
                WHERE doc_type = :docType AND financial_year = :fy
                FOR UPDATE
                """)
                .setParameter("docType", docType)
                .setParameter("fy", financialYear)
                .getSingleResult();

        Object next = entityManager.createNativeQuery("""
                UPDATE org_document_sequences
                SET last_number = last_number + 1, updated_at = NOW()
                WHERE doc_type = :docType AND financial_year = :fy
                RETURNING last_number
                """)
                .setParameter("docType", docType)
                .setParameter("fy", financialYear)
                .getSingleResult();

        long number = ((Number) next).longValue();

        // Credit notes take a distinct series so they cannot be mistaken for invoices.
        String marker = DOC_CREDIT_NOTE.equals(docType) ? "CN/" : "";
        return String.format("%s/%s%s/%05d", resolvedPrefix, marker, financialYear, number);
    }

    /** The last number issued in a series, for reconciliation. Zero when none yet. */
    public long lastIssued(String docType, String financialYear) {
        Object result = entityManager.createNativeQuery("""
                SELECT COALESCE(MAX(last_number), 0) FROM org_document_sequences
                WHERE doc_type = :docType AND financial_year = :fy
                """)
                .setParameter("docType", docType)
                .setParameter("fy", financialYear)
                .getSingleResult();
        return result != null ? ((Number) result).longValue() : 0L;
    }
}
