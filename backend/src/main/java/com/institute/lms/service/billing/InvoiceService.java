package com.institute.lms.service.billing;

import com.institute.lms.entity.*;
import com.institute.lms.exception.BadRequestException;
import com.institute.lms.exception.ErrorCode;
import com.institute.lms.exception.PaymentException;
import com.institute.lms.exception.ResourceNotFoundException;
import com.institute.lms.repository.*;
import com.institute.lms.service.subscription.SubscriptionLifecycleService;
import com.institute.lms.subscription.BillingEventType;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

/**
 * Raises and settles invoices.
 *
 * <p>Three rules run through everything here:
 *
 * <p><strong>A draft is editable; an issued invoice is not.</strong> Issuing allocates
 * the statutory number and snapshots both parties. After that a correction is a credit
 * note, never an edit — otherwise the number series describes documents that no longer
 * exist in the form they were sent.
 *
 * <p><strong>Totals are always derived from lines.</strong> Nothing sets a header total
 * directly, because a header that can disagree with its own lines is the first thing a
 * customer notices.
 *
 * <p><strong>Nothing here charges anyone.</strong> There is no payment gateway;
 * {@link #recordPayment} books money the platform team has already received by bank
 * transfer, UPI, cheque or against a purchase order.
 */
@Service
public class InvoiceService {

    private static final Logger log = LoggerFactory.getLogger(InvoiceService.class);

    private final OrgInvoiceRepository invoiceRepository;
    private final OrgPaymentRepository paymentRepository;
    private final OrgCreditNoteRepository creditNoteRepository;
    private final OrganizationRepository organizationRepository;
    private final SystemConfigRepository systemConfigRepository;
    private final InvoiceNumberService numberService;
    private final GstCalculator gstCalculator;
    private final SubscriptionLifecycleService lifecycleService;

    public InvoiceService(OrgInvoiceRepository invoiceRepository,
                          OrgPaymentRepository paymentRepository,
                          OrgCreditNoteRepository creditNoteRepository,
                          OrganizationRepository organizationRepository,
                          SystemConfigRepository systemConfigRepository,
                          InvoiceNumberService numberService,
                          GstCalculator gstCalculator,
                          SubscriptionLifecycleService lifecycleService) {
        this.invoiceRepository = invoiceRepository;
        this.paymentRepository = paymentRepository;
        this.creditNoteRepository = creditNoteRepository;
        this.organizationRepository = organizationRepository;
        this.systemConfigRepository = systemConfigRepository;
        this.numberService = numberService;
        this.gstCalculator = gstCalculator;
        this.lifecycleService = lifecycleService;
    }

    /** A line to bill, before tax is worked out. */
    public record LineRequest(
            String lineType,
            String description,
            String hsnSacCode,
            BigDecimal qty,
            String unitLabel,
            BigDecimal unitPrice,
            BigDecimal discount,
            BigDecimal taxRatePct,
            String addonCode,
            String calculation
    ) {
        public static LineRequest of(String type, String description, BigDecimal unitPrice, String sac) {
            return new LineRequest(type, description, sac, BigDecimal.ONE, null,
                    unitPrice, BigDecimal.ZERO, new BigDecimal("18.00"), null, null);
        }
    }

    // =====================================================================
    // Creating
    // =====================================================================

    /**
     * Creates a draft invoice with tax computed per line.
     *
     * <p>Left as a draft on purpose: nothing is numbered or sent until someone reviews
     * it and calls {@link #issue}.
     */
    @Transactional
    public OrgInvoice createDraft(Long organizationId, String invoiceType,
                                  List<LineRequest> lineRequests, String actor) {
        Organization org = organizationRepository.findById(organizationId)
                .orElseThrow(() -> ResourceNotFoundException.of("Organization", organizationId));

        if (lineRequests == null || lineRequests.isEmpty()) {
            throw new BadRequestException("An invoice needs at least one line.");
        }

        OrgInvoice invoice = new OrgInvoice();
        invoice.setOrganizationId(organizationId);
        invoice.setInvoiceType(invoiceType != null ? invoiceType : OrgInvoice.TYPE_MANUAL);
        invoice.setStatus(OrgInvoice.STATUS_DRAFT);
        invoice.setInvoiceDate(LocalDate.now());
        invoice.setDueDate(LocalDate.now().plusDays(configInt("billing.invoice.dueDays", 15)));
        invoice.setFinancialYear(numberService.currentFinancialYear());
        invoice.setCreatedBy(actor);
        invoice.setPoNumber(org.getPoNumber());

        applyParties(invoice, org);

        String sellerState = invoice.getSellerStateCode();
        String customerState = invoice.getCustomerStateCode();

        for (LineRequest request : lineRequests) {
            invoice.addLine(buildLine(request, sellerState, customerState));
        }
        invoice.recalculate();

        // A draft number is not allocated yet, but the column is NOT NULL — use a
        // placeholder that is obviously not a real invoice number, so a draft can never
        // be mistaken for an issued document.
        invoice.setInvoiceNumber("DRAFT-" + System.nanoTime());

        return invoiceRepository.save(invoice);
    }

    private OrgInvoiceLine buildLine(LineRequest request, String sellerState, String customerState) {
        OrgInvoiceLine line = new OrgInvoiceLine();
        line.setLineType(request.lineType() != null ? request.lineType() : OrgInvoiceLine.TYPE_PLAN);
        line.setDescription(request.description());
        line.setHsnSacCode(request.hsnSacCode());
        line.setQty(request.qty() != null ? request.qty() : BigDecimal.ONE);
        line.setUnitLabel(request.unitLabel());
        line.setUnitPrice(request.unitPrice() != null ? request.unitPrice() : BigDecimal.ZERO);
        line.setDiscount(request.discount() != null ? request.discount() : BigDecimal.ZERO);
        line.setTaxRatePct(request.taxRatePct() != null ? request.taxRatePct() : new BigDecimal("18.00"));
        line.setAddonCode(request.addonCode());
        line.setCalculation(request.calculation());

        BigDecimal gross = line.getUnitPrice().multiply(line.getQty());
        BigDecimal net = gross.subtract(line.getDiscount());
        if (net.signum() < 0) {
            net = BigDecimal.ZERO;
        }

        GstCalculator.GstBreakup tax = gstCalculator.calculate(
                net, line.getTaxRatePct(), sellerState, customerState, false);

        line.setTaxableValue(tax.taxableValue());
        line.setCgst(tax.cgst());
        line.setSgst(tax.sgst());
        line.setIgst(tax.igst());
        line.setLineTotal(tax.total());
        return line;
    }

    /** Copies both parties onto the invoice, so it reproduces exactly what was sent. */
    private void applyParties(OrgInvoice invoice, Organization org) {
        invoice.setSellerLegalName(config("billing.seller.legalName", ""));
        invoice.setSellerGstin(config("billing.seller.gstin", ""));
        invoice.setSellerAddress(config("billing.seller.address", ""));
        invoice.setSellerStateCode(config("billing.seller.stateCode", ""));

        invoice.setCustomerLegalName(org.getLegalName() != null ? org.getLegalName() : org.getName());
        invoice.setCustomerGstin(org.getGstin());
        invoice.setCustomerAddress(org.getBillingAddress());
        invoice.setCustomerStateCode(org.getStateCode());
        invoice.setPlaceOfSupply(org.getPlaceOfSupply());
    }

    // =====================================================================
    // Issuing
    // =====================================================================

    /**
     * Issues a draft: allocates the statutory number and freezes the document.
     *
     * <p>Refuses when the place of supply is missing. That is not pedantry — without it
     * the CGST/SGST-versus-IGST split is a guess, and an invoice carrying the wrong head
     * of tax cannot be filed by us or claimed by the customer. Better to stop here than
     * to send something that has to be credited and reissued.
     */
    @Transactional
    public OrgInvoice issue(Long invoiceId, String actor) {
        OrgInvoice invoice = require(invoiceId);
        if (!invoice.isEditable()) {
            throw new BadRequestException(ErrorCode.INVOICE_NOT_PAYABLE,
                    "Invoice " + invoice.getInvoiceNumber() + " has already been issued.");
        }

        if (isBlank(invoice.getSellerGstin()) || isBlank(invoice.getSellerStateCode())) {
            throw new BadRequestException(ErrorCode.GSTIN_INVALID,
                    "Our own GSTIN and state code are not configured, so a compliant invoice cannot be "
                            + "raised. Set billing.seller.gstin and billing.seller.stateCode in Settings.");
        }
        if (isBlank(invoice.getCustomerStateCode()) || isBlank(invoice.getPlaceOfSupply())) {
            throw new BadRequestException(ErrorCode.GSTIN_INVALID, String.format(
                    "%s has no place of supply recorded, so GST cannot be split correctly between "
                            + "CGST/SGST and IGST. Add it to the organization's billing details first.",
                    invoice.getCustomerLegalName()));
        }

        // Recompute the tax split now that the parties are final — the draft may have
        // been created before the customer's state was filled in.
        for (OrgInvoiceLine line : invoice.getLines()) {
            BigDecimal net = line.getUnitPrice().multiply(line.getQty()).subtract(line.getDiscount());
            GstCalculator.GstBreakup tax = gstCalculator.calculate(net, line.getTaxRatePct(),
                    invoice.getSellerStateCode(), invoice.getCustomerStateCode(), false);
            line.setTaxableValue(tax.taxableValue());
            line.setCgst(tax.cgst());
            line.setSgst(tax.sgst());
            line.setIgst(tax.igst());
            line.setLineTotal(tax.total());
        }
        invoice.recalculate();

        String prefix = config("billing.invoice.prefix", "AX");
        invoice.setInvoiceNumber(numberService.allocate(
                InvoiceNumberService.DOC_INVOICE, prefix, invoice.getInvoiceDate()));
        invoice.setFinancialYear(numberService.financialYearOf(invoice.getInvoiceDate()));
        invoice.setStatus(OrgInvoice.STATUS_ISSUED);
        invoice.setIssuedAt(LocalDateTime.now());

        OrgInvoice saved = invoiceRepository.save(invoice);

        lifecycleService.recordEvent(saved.getOrganizationId(), saved.getSubscriptionInstanceId(),
                BillingEventType.INVOICE_ISSUED, null, null, actor,
                String.format("Invoice %s issued for %s %s.",
                        saved.getInvoiceNumber(), saved.getTotal().toPlainString(), saved.getCurrency()),
                null);

        log.info("Issued invoice {} for organization {} totalling {}",
                saved.getInvoiceNumber(), saved.getOrganizationId(), saved.getTotal());
        return saved;
    }

    /** Voids an invoice. Only permitted before any payment has landed against it. */
    @Transactional
    public OrgInvoice voidInvoice(Long invoiceId, String reason, String actor) {
        OrgInvoice invoice = require(invoiceId);
        if (OrgInvoice.STATUS_VOID.equals(invoice.getStatus())) {
            throw new BadRequestException("That invoice is already void.");
        }
        if (invoice.getAmountPaid().signum() > 0) {
            // Cancelling a document money has been received against would leave the
            // payment orphaned; the correct instrument is a credit note.
            throw new BadRequestException(ErrorCode.INVOICE_NOT_PAYABLE,
                    "Payments have already been recorded against " + invoice.getInvoiceNumber()
                            + ", so it cannot be voided. Raise a credit note instead.");
        }
        if (isBlank(reason)) {
            throw BadRequestException.field("reason", "is required when voiding an invoice");
        }

        invoice.setStatus(OrgInvoice.STATUS_VOID);
        invoice.setVoidReason(reason);
        invoice.setVoidedAt(LocalDateTime.now());
        invoice.setBalanceDue(BigDecimal.ZERO);
        OrgInvoice saved = invoiceRepository.save(invoice);

        lifecycleService.recordEvent(saved.getOrganizationId(), saved.getSubscriptionInstanceId(),
                BillingEventType.INVOICE_VOIDED, null, null, actor,
                "Invoice " + saved.getInvoiceNumber() + " voided: " + reason, null);
        return saved;
    }

    // =====================================================================
    // Settling
    // =====================================================================

    /**
     * Records money received.
     *
     * <p>The invoice balance is recomputed by summing cleared payments rather than by
     * incrementing a running total, so a bounced cheque marked as such correctly
     * reopens the balance instead of leaving it permanently understated.
     */
    @Transactional
    public OrgPayment recordPayment(Long invoiceId, BigDecimal amount, String method,
                                    String reference, LocalDateTime paidAt, String actor, String notes) {
        OrgInvoice invoice = require(invoiceId);
        if (!invoice.isPayable()) {
            throw PaymentException.notPayable(invoice.getInvoiceNumber(), invoice.getStatus());
        }
        if (amount == null || amount.signum() <= 0) {
            throw BadRequestException.field("amount", "must be greater than zero");
        }
        BigDecimal alreadyPaid = paymentRepository.totalPaidFor(invoiceId);
        if (alreadyPaid.add(amount).compareTo(invoice.getTotal()) > 0) {
            throw new BadRequestException(String.format(
                    "That would take payments to %s against an invoice of %s. Record the excess as a "
                            + "separate credit if it is genuinely an overpayment.",
                    alreadyPaid.add(amount).toPlainString(), invoice.getTotal().toPlainString()));
        }

        OrgPayment payment = new OrgPayment();
        payment.setOrganizationId(invoice.getOrganizationId());
        payment.setInvoiceId(invoiceId);
        payment.setAmount(amount);
        payment.setCurrency(invoice.getCurrency());
        payment.setMethod(method != null ? method : OrgPayment.METHOD_BANK_TRANSFER);
        payment.setStatus(OrgPayment.STATUS_CLEARED);
        payment.setReference(reference);
        payment.setPaidAt(paidAt != null ? paidAt : LocalDateTime.now());
        payment.setRecordedBy(actor);
        payment.setNotes(notes);
        OrgPayment saved = paymentRepository.save(payment);

        refreshInvoiceBalance(invoice);

        lifecycleService.recordEvent(invoice.getOrganizationId(), invoice.getSubscriptionInstanceId(),
                BillingEventType.PAYMENT_RECORDED, null, null, actor,
                String.format("%s %s received against %s (%s).",
                        amount.toPlainString(), invoice.getCurrency(),
                        invoice.getInvoiceNumber(), payment.getMethod()),
                null);
        return saved;
    }

    /** Recomputes an invoice's paid total and status from its cleared payments. */
    @Transactional
    public OrgInvoice refreshInvoiceBalance(OrgInvoice invoice) {
        BigDecimal paid = paymentRepository.totalPaidFor(invoice.getId());
        invoice.applyPaymentTotals(paid);
        return invoiceRepository.save(invoice);
    }

    /**
     * Issues a credit note against an invoice.
     *
     * <p>Capped at the invoice total less anything already credited, because crediting
     * more than was ever invoiced is an error every time it happens.
     */
    @Transactional
    public OrgCreditNote issueCreditNote(Long invoiceId, BigDecimal amount, String reasonCode,
                                         String reason, String actor) {
        OrgInvoice invoice = require(invoiceId);
        if (amount == null || amount.signum() <= 0) {
            throw BadRequestException.field("amount", "must be greater than zero");
        }

        BigDecimal alreadyCredited = creditNoteRepository.totalCreditedFor(invoiceId);
        BigDecimal creditable = invoice.getTotal().subtract(alreadyCredited);
        if (amount.compareTo(creditable) > 0) {
            throw new BadRequestException(ErrorCode.CREDIT_NOTE_EXCEEDS_INVOICE, String.format(
                    "Only %s of %s remains creditable on %s (%s already credited).",
                    creditable.toPlainString(), invoice.getTotal().toPlainString(),
                    invoice.getInvoiceNumber(), alreadyCredited.toPlainString()));
        }

        // Reverse tax in the same proportion and on the same head as the original, so
        // the credit note actually offsets what was charged.
        BigDecimal proportion = invoice.getTotal().signum() > 0
                ? amount.divide(invoice.getTotal(), 10, java.math.RoundingMode.HALF_UP)
                : BigDecimal.ZERO;

        OrgCreditNote note = new OrgCreditNote();
        note.setOrganizationId(invoice.getOrganizationId());
        note.setInvoiceId(invoiceId);
        note.setFinancialYear(numberService.currentFinancialYear());
        note.setCreditNoteNumber(numberService.allocate(
                InvoiceNumberService.DOC_CREDIT_NOTE, config("billing.invoice.prefix", "AX"), LocalDate.now()));
        note.setReasonCode(reasonCode != null ? reasonCode : OrgCreditNote.REASON_OTHER);
        note.setReason(reason);
        note.setCurrency(invoice.getCurrency());
        note.setTaxableValue(scale(invoice.getTaxableValue().multiply(proportion)));
        note.setCgst(scale(invoice.getCgst().multiply(proportion)));
        note.setSgst(scale(invoice.getSgst().multiply(proportion)));
        note.setIgst(scale(invoice.getIgst().multiply(proportion)));
        note.setTotal(amount);
        note.setIssuedBy(actor);

        OrgCreditNote saved = creditNoteRepository.save(note);

        // A fully credited invoice is marked as such rather than left looking unpaid.
        if (alreadyCredited.add(amount).compareTo(invoice.getTotal()) >= 0) {
            invoice.setStatus(OrgInvoice.STATUS_CREDITED);
            invoice.setBalanceDue(BigDecimal.ZERO);
            invoiceRepository.save(invoice);
        }

        lifecycleService.recordEvent(invoice.getOrganizationId(), invoice.getSubscriptionInstanceId(),
                BillingEventType.CREDIT_NOTE_ISSUED, null, null, actor,
                String.format("Credit note %s for %s against %s.",
                        saved.getCreditNoteNumber(), amount.toPlainString(), invoice.getInvoiceNumber()),
                null);
        return saved;
    }

    // =====================================================================
    // Reading
    // =====================================================================

    public List<OrgInvoice> forOrganization(Long organizationId) {
        return invoiceRepository.findByOrganizationIdOrderByInvoiceDateDescIdDesc(organizationId);
    }

    public BigDecimal outstandingFor(Long organizationId) {
        return invoiceRepository.outstandingFor(organizationId);
    }

    public Optional<OrgInvoice> findByNumber(String invoiceNumber) {
        return invoiceRepository.findByInvoiceNumber(invoiceNumber);
    }

    public OrgInvoice require(Long invoiceId) {
        return invoiceRepository.findById(invoiceId)
                .orElseThrow(() -> new ResourceNotFoundException(ErrorCode.INVOICE_NOT_FOUND,
                        "Invoice " + invoiceId + " was not found"));
    }

    /**
     * Marks overdue invoices as such. Idempotent, so the scheduler can call it freely.
     *
     * @return how many changed
     */
    @Transactional
    public int markOverdue() {
        int changed = 0;
        for (OrgInvoice invoice : invoiceRepository.findOverdue(LocalDate.now())) {
            if (!OrgInvoice.STATUS_OVERDUE.equals(invoice.getStatus())) {
                invoice.setStatus(OrgInvoice.STATUS_OVERDUE);
                invoiceRepository.save(invoice);
                changed++;
            }
        }
        return changed;
    }

    // =====================================================================
    // Helpers
    // =====================================================================

    private String config(String key, String fallback) {
        return systemConfigRepository.findByConfigKey(key)
                .map(SystemConfig::getConfigValue)
                .filter(v -> v != null && !v.isBlank())
                .orElse(fallback);
    }

    private int configInt(String key, int fallback) {
        try {
            return Integer.parseInt(config(key, String.valueOf(fallback)).trim());
        } catch (NumberFormatException e) {
            return fallback;
        }
    }

    private boolean isBlank(String s) {
        return s == null || s.isBlank();
    }

    private BigDecimal scale(BigDecimal value) {
        return value.setScale(2, java.math.RoundingMode.HALF_UP);
    }
}
