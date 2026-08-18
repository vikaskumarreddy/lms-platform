package com.institute.lms.service;

import com.institute.lms.entity.User;
import com.institute.lms.repository.UserRepository;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class UserDetailsServiceImpl implements UserDetailsService {

    private final UserRepository userRepository;

    public UserDetailsServiceImpl(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @Override
    public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
        // Credential lookup for JWT validation. This runs inside the Spring Security
        // filter chain, BEFORE the MVC TenantInterceptor has resolved/set the org context,
        // so the user table lookup MUST NOT be tenant-filtered (Hibernate's @TenantId
        // DISCRIMINATOR would otherwise scope it to the "-1" no-tenant sentinel and find
        // nothing). findAnyByEmail is a native query that bypasses the discriminator; the
        // token's organization_id claim drives all per-org scoping downstream.
        User user = userRepository.findAnyByEmail(username)
                .orElseThrow(() -> new UsernameNotFoundException("User not found with email: " + username));

        return new org.springframework.security.core.userdetails.User(
                user.getUsername(),
                user.getPassword(),
                List.of(new SimpleGrantedAuthority("ROLE_" + user.getRole().name()))
        );
    }
}
