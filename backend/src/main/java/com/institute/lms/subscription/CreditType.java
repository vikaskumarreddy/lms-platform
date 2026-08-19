package com.institute.lms.subscription;

/** Prepaid communication credit pools a tenant can hold. */
public enum CreditType {

    SMS("SMS", "SMS_CREDITS"),
    WHATSAPP("WhatsApp message", "WHATSAPP_CREDITS"),
    EMAIL("Email", "EMAIL_CREDITS");

    private final String label;
    /** The add-on code that tops this pool up. */
    private final String addonCode;

    CreditType(String label, String addonCode) {
        this.label = label;
        this.addonCode = addonCode;
    }

    public String getLabel() {
        return label;
    }

    public String getAddonCode() {
        return addonCode;
    }

    public static CreditType fromName(String raw) {
        if (raw == null) {
            return null;
        }
        for (CreditType t : values()) {
            if (t.name().equalsIgnoreCase(raw.trim())) {
                return t;
            }
        }
        return null;
    }
}
