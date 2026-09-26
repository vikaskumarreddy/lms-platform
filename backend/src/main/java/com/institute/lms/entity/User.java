package com.institute.lms.entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.NoArgsConstructor;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.Set;

@Entity
@Table(name = "users")
@Data
@NoArgsConstructor
@EqualsAndHashCode(callSuper = true, exclude = {"enrollments", "progress", "attendance", "feedback", "comments", "bookmarks"})
public class User extends BaseEntity implements UserDetails {

    @Column(unique = true, nullable = false)
    private String email;

    @Column(nullable = false)
    private String password;

    @Column(nullable = false)
    private String name;

    @Column(unique = true)
    private String phone;

    @Column(unique = true)
    private String username;

    @Enumerated(EnumType.STRING)
    private UserRole role;

    @Column(name = "is_active")
    private Boolean isActive = true;

    @Column(name = "is_email_verified")
    private Boolean isEmailVerified = false;

    @Column(name = "last_login")
    private LocalDateTime lastLogin;

                    
    @Column(name = "plan_id")
    private Long planId;

    @Column(name = "batch_id")
    private Long batchId;

    /** Ghost platform super-admin (admin@axisora.com) auto-provisioned in every tenant.
     *  Hidden from tenant admin lists and treated as the platform owner when present. */
    @Column(name = "is_ghost")
    private Boolean isGhost = false;

    @Column(name = "linkedin")
    private String linkedin;

    @Column(name = "github")
    private String github;

    /** Firebase Cloud Messaging device token, refreshed by the mobile app on login/token-rotation. */
    @Column(name = "fcm_token", columnDefinition = "TEXT")
    private String fcmToken;

    // ---- Parent/guardian contact (used for daily-attendance absentee alerts etc.) ----

    @Column(name = "parent_name")
    private String parentName;

    @Column(name = "parent_phone", length = 30)
    private String parentPhone;

    @Column(name = "parent_email")
    private String parentEmail;

    /** Channel to notify the parent through. Defaults to PUSH (no behavior change for existing students). */
    @Enumerated(EnumType.STRING)
    @Column(name = "notify_medium", length = 20)
    private NotifyMedium notifyMedium = NotifyMedium.PUSH;

    /** Extra/custom registration fields stored as JSON string. */
    @Column(name = "custom_fields", columnDefinition = "TEXT")
    private String customFields;


    @OneToMany(mappedBy = "user", cascade = CascadeType.ALL)
    @JsonIgnore
    private Set<Enrollment> enrollments;

    @OneToMany(mappedBy = "user", cascade = CascadeType.ALL)
    @JsonIgnore
    private Set<Progress> progress;

    @OneToMany(mappedBy = "user", cascade = CascadeType.ALL)
    @JsonIgnore
    private Set<Attendance> attendance;

    @OneToMany(mappedBy = "user", cascade = CascadeType.ALL)
    @JsonIgnore
    private Set<Feedback> feedback;

    @OneToMany(mappedBy = "user", cascade = CascadeType.ALL)
    @JsonIgnore
    private Set<Comment> comments;

    @OneToMany(mappedBy = "user", cascade = CascadeType.ALL)
    @JsonIgnore
    private Set<Bookmark> bookmarks;

    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {
        return role != null ? List.of(new SimpleGrantedAuthority("ROLE_" + role.name())) : new ArrayList<>();
    }

    @Override
    public String getUsername() {
        return email;
    }

    @Override
    public String getPassword() {
        return password;
    }

    @Override
    public boolean isAccountNonExpired() {
        return true;
    }

    @Override
    public boolean isAccountNonLocked() {
        return true;
    }

    @Override
    public boolean isCredentialsNonExpired() {
        return true;
    }

    @Override
    public boolean isEnabled() {
        return isActive != null && isActive;
    }

    public enum UserRole {
        ADMIN, INSTRUCTOR, STUDENT, INSTITUTE_ADMIN
    }
}