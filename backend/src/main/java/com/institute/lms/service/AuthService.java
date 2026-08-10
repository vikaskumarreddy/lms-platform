package com.institute.lms.service;

import com.institute.lms.dto.auth.AuthResponse;
import com.institute.lms.dto.auth.LoginRequest;
import com.institute.lms.dto.auth.RegisterRequest;
import com.institute.lms.entity.User;
import com.institute.lms.repository.UserRepository;
import com.institute.lms.security.JwtService;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.List;

@Service
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;

    @Value("${jwt.expiration}")
    private long jwtExpiration;

    public AuthService(UserRepository userRepository, PasswordEncoder passwordEncoder, JwtService jwtService) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
    }

    public AuthResponse login(LoginRequest request) {
        User user = userRepository.findByEmail(request.getEmail())
                .orElseThrow(() -> new RuntimeException("Invalid email or password"));

        if (!passwordEncoder.matches(request.getPassword(), user.getPassword())) {
            throw new RuntimeException("Invalid email or password");
        }

        // Update last login
        user.setLastLogin(LocalDateTime.now());
        userRepository.save(user);

        return buildAuthResponse(user);
    }

    public AuthResponse register(RegisterRequest request) {
        if (userRepository.existsByEmail(request.getEmail())) {
            throw new RuntimeException("Email already registered");
        }

        User user = new User();
        user.setName(request.getName());
        user.setEmail(request.getEmail());
        user.setPassword(passwordEncoder.encode(request.getPassword()));
        user.setPhone(request.getPhone());

        // Default role is STUDENT unless specified
        String roleStr = request.getRole() != null ? request.getRole().toUpperCase() : "STUDENT";
        User.UserRole role;
        try {
            role = User.UserRole.valueOf(roleStr);
        } catch (IllegalArgumentException e) {
            role = User.UserRole.STUDENT;
        }
        user.setRole(role);
        user.setIsActive(true);
        user.setIsEmailVerified(false);

        userRepository.save(user);

        return buildAuthResponse(user);
    }

    private AuthResponse buildAuthResponse(User user) {
        String accessToken = jwtService.generateToken(user);
        String refreshToken = jwtService.generateRefreshToken(user);
        String roleName = user.getRole() != null ? user.getRole().name() : "STUDENT";

        return AuthResponse.builder()
                .accessToken(accessToken)
                .refreshToken(refreshToken)
                .tokenType("Bearer")
                .expiresIn(jwtExpiration)
                .user(AuthResponse.UserInfo.builder()
                        .id(user.getId())
                        .email(user.getEmail())
                        .fullName(user.getName())
                        .role(roleName)
                        .roles(List.of(roleName))
                        .planId(user.getPlanId())
                        .batchId(user.getBatchId())
                        .build())
                .build();
    }
}