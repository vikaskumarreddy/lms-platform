package com.institute.lms.service.payment;

import com.institute.lms.entity.PaymentGateway;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/** Looks up the {@link PaymentGatewayService} adapter registered for a given {@link PaymentGateway}. */
@Component
public class PaymentGatewayResolver {
    private final Map<PaymentGateway, PaymentGatewayService> byGateway;

    public PaymentGatewayResolver(List<PaymentGatewayService> services) {
        this.byGateway = services.stream()
                .collect(Collectors.toMap(PaymentGatewayService::getGateway, s -> s));
    }

    public PaymentGatewayService resolve(PaymentGateway gateway) {
        PaymentGatewayService service = byGateway.get(gateway != null ? gateway : PaymentGateway.RAZORPAY);
        if (service == null) {
            throw new IllegalStateException("No payment gateway adapter registered for " + gateway);
        }
        return service;
    }
}
