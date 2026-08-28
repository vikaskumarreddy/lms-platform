package com.institute.lms.dto.payment;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class PaymentHistoryEntryDTO {
    private String method;
    private String status;
    private Long amount;
    private String currency;
    private LocalDateTime date;
    private String razorpayOrderId;
    private String razorpayPaymentId;
    private String notes;
}
