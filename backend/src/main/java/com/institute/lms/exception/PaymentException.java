package com.institute.lms.exception;

/**
 * A billing or payment operation could not be completed — a failed charge, an
 * invoice that is not in a payable state, or an unreachable gateway.
 */
public class PaymentException extends ApiException {

    public PaymentException(String message) {
        super(ErrorCode.PAYMENT_FAILED, message);
    }

    public PaymentException(ErrorCode code, String message) {
        super(code, message);
    }

    public PaymentException(ErrorCode code, String message, Throwable cause) {
        super(code, message, cause);
    }

    /** The invoice exists but its current status forbids the attempted action. */
    public static PaymentException notPayable(String invoiceNumber, String status) {
        PaymentException ex = new PaymentException(ErrorCode.INVOICE_NOT_PAYABLE,
                "Invoice " + invoiceNumber + " cannot be paid while it is " + status);
        ex.detail("invoiceNumber", invoiceNumber).detail("invoiceStatus", status);
        return ex;
    }
}
