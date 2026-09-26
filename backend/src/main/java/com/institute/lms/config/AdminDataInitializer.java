package com.institute.lms.config;

import com.institute.lms.entity.Organization;
import com.institute.lms.entity.User;
import com.institute.lms.repository.OrganizationRepository;
import com.institute.lms.repository.UserRepository;
import com.institute.lms.util.OrganizationContext;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.crypto.password.PasswordEncoder;

@Configuration
public class AdminDataInitializer {

    @Bean
    public CommandLineRunner seedAdminUser(UserRepository userRepository, OrganizationRepository organizationRepository,
                                            PasswordEncoder passwordEncoder, OrganizationContext organizationContext) {
        return args -> {
            // Find default organization (by slug 'axisora', by id 1, or by slug 'admin')
            Organization defaultOrg = organizationRepository.findBySlug("axisora")
                    .or(() -> organizationRepository.findById(1L))
                    .or(() -> organizationRepository.findBySlug("admin"))
                    .orElseGet(() -> {
                        Organization org = new Organization();
                        org.setName("Axisora");
                        org.setSlug("axisora");
                        org.setDomain("admin.axisoraforge.in");
                        org.setSettings("{}");
                        return organizationRepository.save(org);
                    });

            if (!"axisora".equalsIgnoreCase(defaultOrg.getSlug())) {
                defaultOrg.setSlug("axisora");
                organizationRepository.save(defaultOrg);
            }

            // This runner executes at application bootstrap, outside any HTTP request,
            // so TenantInterceptor never populates OrganizationContext and
            // TenantIdentifierResolverImpl would otherwise resolve the "-1" no-tenant
            // sentinel for this thread. The User entity below is explicitly scoped to
            // defaultOrg, so the tenant context must be set to match it for the
            // duration of these tenant-scoped repository calls (both the existsByEmail
            // lookup and the save), or Hibernate's @TenantId validation rejects the
            // assigned organizationId as differing from the current tenant identifier.
            organizationContext.setCurrentOrganization(defaultOrg);
            try {
                // Seed admin user linked to the default organization
                if (!userRepository.existsByEmail("admin@axisora.com")) {
                    User admin = new User();
                    admin.setEmail("admin@axisora.com");
                    admin.setPassword(passwordEncoder.encode("admin123"));
                    admin.setName("Admin");
                    admin.setRole(User.UserRole.ADMIN);
                    admin.setIsActive(true);
                    admin.setIsEmailVerified(true);
                    admin.setOrganizationId(defaultOrg.getId());
                    userRepository.save(admin);
                }
            } finally {
                organizationContext.clear();
            }
        };
    }
}