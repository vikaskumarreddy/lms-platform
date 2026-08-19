package com.institute.lms.subscription;

/**
 * Every feature a plan can switch on, or quantify.
 *
 * <p>The constant name is the JSON key inside {@code org_subscriptions.entitlements}
 * and {@code org_subscription_instances.entitlements_snapshot}. Only keys that are
 * <em>granted</em> are stored — an absent key means "not included" (false for a
 * {@link ValueType#BOOLEAN}, zero for a {@link ValueType#NUMBER}). That keeps the
 * seed JSON readable and means adding a new entitlement does not require rewriting
 * every existing plan row.
 *
 * <p>{@link ValueType#NUMBER} entitlements exist because several of the commercial
 * inclusions are open-ended as written — "website maintenance" and "limited data
 * migration" would otherwise mean whatever each customer assumed, and two academies
 * on the same price would consume wildly different effort. Quantifying them
 * (pages, revisions, maintenance hours, migration records) makes the boundary
 * checkable, and anything past it routes to the matching add-on.
 *
 * <p>{@link #isSalesQualified()} marks features the platform cannot self-provision
 * today — SSO has no SAML/OIDC implementation, dedicated infrastructure means a
 * separate deployment rather than a flag, and a white-labelled mobile app needs a
 * per-tenant Flutter build and its own store listings. These stay switchable so
 * Enterprise deals can record what was sold, but the UI must present them as
 * "included in your agreement", never as instantly available.
 */
public enum Entitlement {

    // ---- Core platform (all plans) --------------------------------------
    MULTI_TENANT_DASHBOARD(Category.CORE, "Academy dashboard"),
    STUDENT_MOBILE_APP(Category.CORE, "Shared student mobile app"),
    COURSE_MANAGEMENT(Category.ACADEMICS, "Course management"),
    NOTES_AND_MATERIALS(Category.ACADEMICS, "Notes and learning materials"),
    CLASSES(Category.ACADEMICS, "Classes"),
    ASSIGNMENTS_AND_EXAMS(Category.ACADEMICS, "Assignments and examinations"),
    BASIC_PAYMENT_COLLECTION(Category.CORE, "Basic payment collection"),
    RESUME_BUILDER(Category.PLACEMENTS, "Resume builder"),
    CERTIFICATES(Category.ACADEMICS, "Certificates"),
    PLACEMENT_NOTIFICATIONS(Category.PLACEMENTS, "Placement notifications"),
    BASIC_REPORTS(Category.ANALYTICS, "Basic reports"),
    STANDARD_SUPPORT(Category.SUPPORT, "Standard support"),

    // ---- Platform Plus --------------------------------------------------
    BRANDED_WEBSITE(Category.BRANDING, "Branded academy website"),
    CUSTOM_DOMAIN(Category.BRANDING, "Custom domain"),
    WEBSITE_MAINTENANCE(Category.BRANDING, "Website maintenance"),
    ADDITIONAL_BRANDING(Category.BRANDING, "Additional branding options"),
    PRIORITY_SUPPORT(Category.SUPPORT, "Priority support"),
    ASSISTED_ONBOARDING(Category.SERVICES, "Assisted onboarding"),
    DATA_MIGRATION_ASSISTED(Category.SERVICES, "Assisted data migration"),
    ADVANCED_PLACEMENT_MANAGEMENT(Category.PLACEMENTS, "Advanced placement management"),
    ADVANCED_ANALYTICS(Category.ANALYTICS, "Advanced analytics and reports"),
    AUTOMATED_COMMUNICATION(Category.COMMUNICATION, "Automated communication"),
    CUSTOMER_SUCCESS_CONTACT(Category.SUPPORT, "Customer success contact"),
    MULTI_BRANCH(Category.CORE, "Multiple branches"),

    /** Quantified so "website maintenance" has a checkable boundary. */
    WEBSITE_PAGES_INCLUDED(Category.BRANDING, "Website pages included", ValueType.NUMBER),
    WEBSITE_REVISIONS_INCLUDED(Category.BRANDING, "Website revisions included", ValueType.NUMBER),
    MAINTENANCE_HOURS_PER_QUARTER(Category.BRANDING, "Maintenance hours per quarter", ValueType.NUMBER),
    /** Bounds "limited data migration"; beyond this, the advanced-migration add-on applies. */
    MIGRATION_RECORDS_INCLUDED(Category.SERVICES, "Records included in migration", ValueType.NUMBER),

    // ---- Managed Academy ------------------------------------------------
    PLATFORM_ADMINISTRATION(Category.SERVICES, "Website and platform administration"),
    STUDENT_SUPPORT_DESK(Category.SERVICES, "Student support"),
    COURSE_ADMINISTRATION(Category.SERVICES, "Course administration"),
    MONTHLY_REPORTING(Category.ANALYTICS, "Monthly reporting"),
    /** Deliberately "allocated", never unlimited — the hours are finite and metered. */
    OPERATIONAL_SUPPORT_ALLOCATED(Category.SERVICES, "Allocated operational support"),
    TRAINING_SUPPORT_ALLOCATED(Category.SERVICES, "Allocated training and faculty assistance"),
    DEDICATED_ACCOUNT_MANAGER(Category.SUPPORT, "Dedicated account manager"),
    DEFINED_SLA(Category.SUPPORT, "Defined service-level agreement"),
    OPERATIONAL_SUPPORT_HOURS_PER_MONTH(Category.SERVICES, "Operational support hours per month", ValueType.NUMBER),

    // ---- Enterprise -----------------------------------------------------
    MULTI_ORGANIZATION(Category.ENTERPRISE, "Multiple organizations"),
    SSO(Category.ENTERPRISE, "Single sign-on", ValueType.BOOLEAN, true),
    API_ACCESS(Category.ENTERPRISE, "API access"),
    CUSTOM_ROLES_AND_WORKFLOWS(Category.ENTERPRISE, "Custom roles and workflows"),
    DEDICATED_INFRASTRUCTURE(Category.ENTERPRISE, "Dedicated infrastructure", ValueType.BOOLEAN, true),
    ADVANCED_SECURITY_AUDIT_LOGS(Category.ENTERPRISE, "Advanced security and audit logs"),
    DATA_MIGRATION_FULL(Category.SERVICES, "Full data migration"),
    CUSTOM_REPORTS(Category.ANALYTICS, "Custom reports"),
    WHITE_LABEL_MOBILE_APP(Category.ENTERPRISE, "White-labelled mobile applications", ValueType.BOOLEAN, true),
    CUSTOM_INTEGRATIONS(Category.ENTERPRISE, "Custom integrations", ValueType.BOOLEAN, true),
    USAGE_AND_BILLING_RULES(Category.ENTERPRISE, "Custom usage and billing rules"),

    // ---- Granted by add-ons rather than a plan tier ---------------------
    PREMIUM_SUPPORT(Category.SUPPORT, "Premium support"),
    VIDEO_HOSTING(Category.CORE, "Video hosting and bandwidth");

    public enum ValueType { BOOLEAN, NUMBER }

    public enum Category {
        CORE("Platform"),
        ACADEMICS("Academics"),
        PLACEMENTS("Placements"),
        BRANDING("Website and branding"),
        ANALYTICS("Reports and analytics"),
        COMMUNICATION("Communication"),
        SUPPORT("Support"),
        SERVICES("Managed services"),
        ENTERPRISE("Enterprise");

        private final String label;

        Category(String label) {
            this.label = label;
        }

        public String getLabel() {
            return label;
        }
    }

    private final Category category;
    private final String label;
    private final ValueType valueType;
    private final boolean salesQualified;

    Entitlement(Category category, String label) {
        this(category, label, ValueType.BOOLEAN, false);
    }

    Entitlement(Category category, String label, ValueType valueType) {
        this(category, label, valueType, false);
    }

    Entitlement(Category category, String label, ValueType valueType, boolean salesQualified) {
        this.category = category;
        this.label = label;
        this.valueType = valueType;
        this.salesQualified = salesQualified;
    }

    public Category getCategory() {
        return category;
    }

    public String getLabel() {
        return label;
    }

    public ValueType getValueType() {
        return valueType;
    }

    /**
     * True when the feature requires manual delivery and cannot be provisioned by
     * flipping this flag alone. The Account page must not imply self-service for these.
     */
    public boolean isSalesQualified() {
        return salesQualified;
    }

    /** Lenient lookup for values read back out of JSON; returns null when unrecognised. */
    public static Entitlement fromKey(String key) {
        if (key == null) return null;
        for (Entitlement e : values()) {
            if (e.name().equalsIgnoreCase(key)) {
                return e;
            }
        }
        return null;
    }
}
