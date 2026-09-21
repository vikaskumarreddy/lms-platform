package com.institute.lms.controller;

import com.institute.lms.dto.dashboard.MentorDTO;
import com.institute.lms.entity.User;
import com.institute.lms.repository.UserRepository;
import com.institute.lms.service.MentorService;
import com.institute.lms.util.UserContext;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * Mentors of the logged-in user (and, for admins/faculty, of any user in their
 * organization). Backs the dashboard's "Your Mentors" card.
 */
@RestController
@RequestMapping("/api/mentors")
public class MentorController {

    private final MentorService mentorService;
    private final UserContext userContext;
    private final UserRepository userRepository;

    public MentorController(MentorService mentorService, UserContext userContext,
                            UserRepository userRepository) {
        this.mentorService = mentorService;
        this.userContext = userContext;
        this.userRepository = userRepository;
    }

    /** Mentors of whoever holds the current token — no id needed from the client. */
    @GetMapping("/me")
    public ResponseEntity<List<MentorDTO>> getMyMentors() {
        User me = userContext.currentUser();
        if (me == null) return ResponseEntity.status(401).build();
        return ResponseEntity.ok(mentorService.mentorsFor(me));
    }

    /**
     * Mentors of a specific user. Students may only ask for themselves; admins and
     * faculty use this to see who mentors a given student.
     */
    @GetMapping("/user/{userId}")
    public ResponseEntity<List<MentorDTO>> getMentorsForUser(@PathVariable Long userId) {
        User me = userContext.currentUser();
        if (me == null) return ResponseEntity.status(401).build();

        boolean isSelf = me.getId() != null && me.getId().equals(userId);
        boolean isStaff = me.getRole() == User.UserRole.ADMIN
                || me.getRole() == User.UserRole.INSTITUTE_ADMIN
                || me.getRole() == User.UserRole.INSTRUCTOR;
        if (!isSelf && !isStaff) return ResponseEntity.status(403).build();

        User target = isSelf ? me : userRepository.findById(userId).orElse(null);
        if (target == null) return ResponseEntity.notFound().build();
        return ResponseEntity.ok(mentorService.mentorsFor(target));
    }
}