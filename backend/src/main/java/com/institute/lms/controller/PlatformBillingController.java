package com.institute.lms.controller;

import com.institute.lms.entity.*;
import com.institute.lms.exception.BadRequestException;
import com.institute.lms.repository.OrgCreditNoteRepository;
import com.institute.lms.repository.OrgDunningEventRepository;
import com.institute.lms.repository.OrgInvoiceRepository;
import com.institute.lms.repository.OrgPaymentRepository;
import com.institute.lms.service.billing.CouponService;
import com.institute.lms.service.billing.InvoiceService;
import com.institute.lms.util.UserContext;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Platform billing: invoices, payments, credit notes and coupons.
 *
 * <p>Super-admin only. Tenants see their own invoices read-only through
 * {@code /api/account}.
 */
@RestController
@RequestMapping("/api/platform/billing")
public class PlatformBillingController {

    private final InvoiceService invoiceService;
    private final CouponService couponService;
    private final OrgPaymentRepository paymentRepository;
    private final OrgCreditNoteRepository creditNoteRepository;
    private final OrgDunningEventRepository dunningRepository;
    private final UserContext userContext;

    public PlatformBillingController(InvoiceService invoiceService,
                                     CouponService couponService,
                                     OrgPaymentRepository paymentRepository,
                                     OrgCreditNoteRepository creditNoteRepository,
                                     OrgDunningEventRepository dunningRepository,
                                     UserContext userContext) {
        this.invoiceService = invoiceService;
        this.couponService = couponService;
        this.paymentRepository = paymentRepository;
        this.creditNoteRepository = creditNoteRepository;
        this.dunningRepository = dunningRepository;
        this.userContext = userContext;
    }

    // ---- Invoices -------------------------------------------------------

    @GetMapping("/invoices")
    public List<OrgInvoice> invoices(@RequestParam Long organizationId) {
        userContext.requireSuperAdmin();
        return invoiceService.forOrganization(organizationId);
    }

    @GetMapping("/invoices/{id}")
    public OrgInvoice invoice(@PathVariable Long id) {
        userContext.requireSuperAdmin();
        return invoiceService.require(id);
    }

    /** Creates a draft invoice. Nothing is numbered or sent until it is issued. */
    @PostMapping("/invoices")
    public ResponseEntity<OrgInvoice> createInvoice(@RequestBody Map<String, Object> body) {
        userContext.requireSuperAdmin();
        Long organizationId = asLong(body.get("organizationId"));
        if (organizationId == null) {
            throw BadRequestException.field("organizationId", "is required");
        }

        Object rawLines = body.get("lines");
        if (!(rawLines instanceof List<?> list) || list.isEmpty()) {
            throw BadRequestException.field("lines", "must contain at least one line");
        }

        List<InvoiceService.LineRequest> lines = new ArrayList<>();
        for (Object item : list) {
            if (!(item instanceof Map<?, ?> line)) {
                continue;
            }
            lines.add(new InvoiceService.LineRequest(
                    str(line.get("lineType")),
                    str(line.get("description")),
                    str(line.get("hsnSacCode")),
                    decimal(line.get("qty"), BigDecimal.ONE),
                    str(line.get("unitLabel")),
                    decimal(line.get("unitPrice"), BigDecimal.ZERO),
                    decimal(line.get("discount"), BigDecimal.ZERO),
                    decimal(line.get("taxRatePct"), new BigDecimal("18.00")),
                    str(line.get("addonCode")),
                    str(line.get("calculation"))));
        }

        return ResponseEntity.ok(invoiceService.createDraft(
                organizationId, str(body.get("invoiceType")), lines, actor()));
    }

    @PostMapping("/invoices/{id}/issue")
    public ResponseEntity<OrgInvoice> issue(@PathVariable Long id) {
        userContext.requireSuperAdmin();
        return ResponseEntity.ok(invoiceService.issue(id, actor()));
    }

    @PostMapping("/invoices/{id}/void")
    public ResponseEntity<OrgInvoice> voidInvoice(@PathVariable Long id,
                                                  @RequestBody Map<String, Object> body) {
        userContext.requireSuperAdmin();
        return ResponseEntity.ok(invoiceService.voidInvoice(id, str(body.get("reason")), actor()));
    }

    // ---- Payments -------------------------------------------------------

    /** Books money already received — bank transfer, UPI, cheque, or against a PO. */
    @PostMapping("/invoices/{id}/payments")
    public ResponseEntity<OrgPayment> recordPayment(@PathVariable Long id,
                                                    @RequestBody Map<String, Object> body) {
        userContext.requireSuperAdmin();
        LocalDateTime paidAt = body.get("paidAt") != null
                ? LocalDateTime.parse(body.get("paidAt").toString()) : null;
        return ResponseEntity.ok(invoiceService.recordPayment(
                id, decimal(body.get("amount"), null), str(body.get("method")),
                str(body.get("reference")), paidAt, actor(), str(body.get("notes"))));
    }

    @GetMapping("/payments")
    public List<OrgPayment> payments(@RequestParam Long organizationId) {
        userContext.requireSuperAdmin();
        return paymentRepository.findByOrganizationIdOrderByPaidAtDesc(organizationId);
    }

    // ---- Credit notes ---------------------------------------------------

    @PostMapping("/invoices/{id}/credit-notes")
    public ResponseEntity<OrgCreditNote> creditNote(@PathVariable Long id,
                                                    @RequestBody Map<String, Object> body) {
        userContext.requireSuperAdmin();
        return ResponseEntity.ok(invoiceService.issueCreditNote(id,
                decimal(body.get("amount"), null), str(body.get("reasonCode")),
                str(body.get("reason")), actor()));
    }

    @GetMapping("/credit-notes")
    public List<OrgCreditNote> creditNotes(@RequestParam Long organizationId) {
        userContext.requireSuperAdmin();
        return creditNoteRepository.findByOrganizationIdOrderByIssueDateDesc(organizationId);
    }

    // ---- Coupons --------------------------------------------------------

    @GetMapping("/coupons")
    public List<OrgCoupon> coupons() {
        userContext.requireSuperAdmin();
        return couponService.all();
    }

    @PostMapping("/coupons")
    public ResponseEntity<OrgCoupon> createCoupon(@RequestBody Map<String, Object> body) {
        userContext.requireSuperAdmin();
        return ResponseEntity.ok(couponService.create(body, actor()));
    }

    @PutMapping("/coupons/{id}")
    public ResponseEntity<OrgCoupon> updateCoupon(@PathVariable Long id,
                                                  @RequestBody Map<String, Object> body) {
        userContext.requireSuperAdmin();
        return ResponseEntity.ok(couponService.update(id, body));
    }

    @DeleteMapping("/coupons/{id}")
    public ResponseEntity<Map<String, Object>> deactivateCoupon(@PathVariable Long id) {
        userContext.requireSuperAdmin();
        couponService.deactivate(id);
        return ResponseEntity.ok(Map.of("message", "Coupon deactivated."));
    }

    /** Checks a coupon against a plan and amount without redeeming it. */
    @PostMapping("/coupons/validate")
    public Map<String, Object> validateCoupon(@RequestBody Map<String, Object> body) {
        userContext.requireOrgAdmin();
        CouponService.CouponQuote quote = couponService.quote(
                str(body.get("code")), asLong(body.get("organizationId")),
                str(body.get("planCode")), decimal(body.get("amount"), BigDecimal.ZERO));

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("valid", quote.valid());
        out.put("discount", quote.discount());
        out.put("finalAmount", quote.finalAmount());
        out.put("message", quote.message());
        return out;
    }

    // ---- Dunning --------------------------------------------------------

    @GetMapping("/dunning")
    public List<OrgDunningEvent> dunning(@RequestParam Long organizationId) {
        userContext.requireSuperAdmin();
        return dunningRepository.findByOrganizationIdOrderBySentAtDesc(organizationId);
    }

    /** Recomputes overdue flags on demand, rather than waiting for the sweep. */
    @PostMapping("/mark-overdue")
    public Map<String, Object> markOverdue() {
        userContext.requireSuperAdmin();
        int changed = invoiceService.markOverdue();
        return Map.of("updated", changed);
    }

    // ---- Helpers --------------------------------------------------------

    private String actor() {
        User user = userContext.currentUser();
        return user != null ? user.getEmail() : "platform-admin";
    }

    private String str(Object value) {
        return value != null ? value.toString() : null;
    }

    private Long asLong(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof Number n) {
            return n.longValue();
        }
        try {
            return Long.parseLong(value.toString().trim());
        } catch (NumberFormatException e) {
            return null;
        }
    }

    private BigDecimal decimal(Object value, BigDecimal fallback) {
        if (value == null) {
            return fallback;
        }
        try {
            return new BigDecimal(value.toString().trim());
        } catch (NumberFormatException e) {
            return fallback;
        }
    }
}
