package com.institute.lms.config;

import com.institute.lms.entity.User;
import com.institute.lms.repository.UserRepository;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.crypto.password.PasswordEncoder;

@Configuration
public class AdminDataInitializer {

    @Bean
    public CommandLineRunner seedAdminUser(UserRepository userRepository, PasswordEncoder passwordEncoder) {
        return args -> {
            if (!userRepository.existsByEmail("admin@axisora.com")) {
                User admin = new User();
                admin.setEmail("admin@axisora.com");
                admin.setPassword(passwordEncoder.encode("admin123"));
                admin.setName("Admin");
                admin.setRole(User.UserRole.ADMIN);
                admin.setIsActive(true);
                admin.setIsEmailVerified(true);
                userRepository.save(admin);
            }
        };
    }
}