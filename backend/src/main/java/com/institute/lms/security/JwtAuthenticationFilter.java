package com.institute.lms.security;

import com.institute.lms.repository.UserRepository;
import com.institute.lms.security.JwtService;
import com.institute.lms.service.UserDetailsServiceImpl;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.lang.NonNull;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;

@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private final JwtService jwtService;
    private final UserDetailsServiceImpl userDetailsService;
    private final UserRepository userRepository;

    public JwtAuthenticationFilter(JwtService jwtService, UserDetailsServiceImpl userDetailsService,
                                    UserRepository userRepository) {
        this.jwtService = jwtService;
        this.userDetailsService = userDetailsService;
        this.userRepository = userRepository;
    }

    @Override
    protected void doFilterInternal(
            @NonNull HttpServletRequest request,
            @NonNull HttpServletResponse response,
            @NonNull FilterChain filterChain
    ) throws ServletException, IOException {
        final String authHeader = request.getHeader("Authorization");

        // Never run JWT validation for the public auth endpoints (login/register).
        // Login must be reachable even when the browser still holds a stale/expired
        // Bearer token in localStorage — otherwise the filter below would try to
        // resolve that stale user and abort the request before AuthController runs.
        if ("OPTIONS".equalsIgnoreCase(request.getMethod())) {
            response.setStatus(HttpServletResponse.SC_OK);
            filterChain.doFilter(request, response);
            return;
        }
        String path = request.getRequestURI();
        if (path != null && path.startsWith("/api/auth/")) {
            filterChain.doFilter(request, response);
            return;
        }

        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            filterChain.doFilter(request, response);
            return;
        }

        final String jwt = authHeader.substring(7);

        String username;
        try {
            username = jwtService.extractUsername(jwt);
        } catch (Exception e) {
            filterChain.doFilter(request, response);
            return;
        }

        if (username != null && SecurityContextHolder.getContext().getAuthentication() == null) {
            // Loading/validating the user must never abort the whole request. A stale,
            // expired, or already-revoked token should simply leave the request
            // unauthenticated (the framework then enforces authorization for protected
            // endpoints, and the original controller still serves permitAll endpoints).
            try {
                var userDetails = resolveUserDetails(jwt, username);

                if (userDetails != null && jwtService.isTokenValid(jwt, userDetails)) {
                    UsernamePasswordAuthenticationToken authToken = new UsernamePasswordAuthenticationToken(
                            userDetails,
                            null,
                            userDetails.getAuthorities()
                    );
                    authToken.setDetails(
                            new WebAuthenticationDetailsSource().buildDetails(request)
                    );
                    SecurityContextHolder.getContext().setAuthentication(authToken);
                }
            } catch (Exception ignored) {
                // Invalid/expired/unresolvable user for this token — continue unauthenticated.
            }
        }
        filterChain.doFilter(request, response);
    }

    /**
     * Resolves the authenticated principal for this request. Prefers the token's
     * {@code user_id} claim, resolving directly by primary key (unambiguous — {@code id}
     * is globally unique, unlike email) and returning the real {@code User} entity itself
     * as the principal so {@code UserContext.currentUser()} picks it up without a second
     * lookup. Falls back to the legacy email-based resolution for tokens issued before
     * this claim existed, so already-logged-in sessions are not force-logged-out.
     */
    private UserDetails resolveUserDetails(String jwt, String username) {
        Long userId;
        try {
            userId = jwtService.extractUserId(jwt);
        } catch (Exception e) {
            userId = null;
        }
        if (userId != null) {
            var user = userRepository.findAnyById(userId).orElse(null);
            if (user != null && username.equals(user.getUsername())) {
                return user;
            }
        }
        return userDetailsService.loadUserByUsername(username);
    }
}