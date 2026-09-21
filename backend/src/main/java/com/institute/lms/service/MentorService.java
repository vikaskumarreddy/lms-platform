package com.institute.lms.service;

import com.institute.lms.dto.dashboard.MentorDTO;
import com.institute.lms.entity.Batch;
import com.institute.lms.entity.Course;
import com.institute.lms.entity.Enrollment;
import com.institute.lms.entity.Subscription;
import com.institute.lms.entity.User;
import com.institute.lms.repository.BatchRepository;
import com.institute.lms.repository.CourseRepository;
import com.institute.lms.repository.EnrollmentRepository;
import com.institute.lms.repository.SubscriptionRepository;
import com.institute.lms.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Resolves the mentors a given user actually has, from data the platform already
 * holds — there is no separate "mentor assignment" table to invent.
 *
 * <p>Two relationships already express mentorship, and a student's real set of
 * mentors is the union of them:
 * <ul>
 *   <li>the mentor on the student's {@code batch} (V24, {@code batches.mentor_id}),
 *       i.e. whoever runs their cohort; and</li>
 *   <li>the instructor who owns each course the student is on (either by direct
 *       enrollment or because the course belongs to the student's plan).</li>
 * </ul>
 *
 * <p>This is why the dashboard's "Mentors" card was empty for every student: the
 * card was a hardcoded placeholder, and no endpoint ever joined those two paths.
 */
@Service
public class MentorService {

    private final UserRepository userRepository;
    private final BatchRepository batchRepository;
    private final CourseRepository courseRepository;
    private final EnrollmentRepository enrollmentRepository;
    private final SubscriptionRepository subscriptionRepository;

    public MentorService(UserRepository userRepository,
                         BatchRepository batchRepository,
                         CourseRepository courseRepository,
                         EnrollmentRepository enrollmentRepository,
                         SubscriptionRepository subscriptionRepository) {
        this.userRepository = userRepository;
        this.batchRepository = batchRepository;
        this.courseRepository = courseRepository;
        this.enrollmentRepository = enrollmentRepository;
        this.subscriptionRepository = subscriptionRepository;
    }

    /**
     * Every mentor-shaped relationship this user has: batch mentor first (their
     * primary contact), then course instructors, each course listed once.
     */
    @Transactional(readOnly = true)
    public List<MentorDTO> mentorsFor(User user) {
        if (user == null) return List.of();

        List<MentorDTO> mentors = new ArrayList<>();
        Set<Long> seenMentorIds = new LinkedHashSet<>();

        // 1) The batch mentor — the one person every student in a cohort shares.
        Batch batch = null;
        if (user.getBatchId() != null) {
            batch = batchRepository.findById(user.getBatchId()).orElse(null);
        }
        if (batch != null && batch.getMentorId() != null) {
            User batchMentor = userRepository.findById(batch.getMentorId()).orElse(null);
            if (batchMentor != null && !Boolean.FALSE.equals(batchMentor.getIsActive())) {
                seenMentorIds.add(batchMentor.getId());
                mentors.add(new MentorDTO(
                        batchMentor.getId(),
                        batchMentor.getName(),
                        batchMentor.getEmail(),
                        batchMentor.getPhone(),
                        "Batch Mentor",
                        batch.getName() == null ? "Mentor" : batch.getName(),
                        true,
                        batch.getId(),
                        batch.getName(),
                        List.of()));
            }
        }

        return withCourseMentors(user, batch, mentors, seenMentorIds);
    }

    /**
     * Appends the instructors of the student's courses, accumulating course titles
     * per instructor so one mentor teaching three of the student's courses appears
     * once with all three named.
     */
    private List<MentorDTO> withCourseMentors(User user, Batch batch,
                                              List<MentorDTO> mentors, Set<Long> seenMentorIds) {
        Map<Long, List<String>> courseNamesByInstructor = new LinkedHashMap<>();
        Map<Long, User> instructorById = new LinkedHashMap<>();
        for (Course course : coursesFor(user)) {
            User instructor = course.getInstructor();
            if (instructor == null || Boolean.FALSE.equals(instructor.getIsActive())) continue;
            // A person can be both the batch mentor and a course instructor (the
            // same faculty runs the cohort and teaches one of its courses). They
            // must appear under Faculty as well, so do NOT skip instructors merely
            // because they are already listed as the batch mentor. Instructors are
            // still de-duplicated against each other via instructorById below.
            instructorById.putIfAbsent(instructor.getId(), instructor);
            courseNamesByInstructor
                    .computeIfAbsent(instructor.getId(), key -> new ArrayList<>())
                    .add(course.getTitle());
        }
        for (Map.Entry<Long, User> entry : instructorById.entrySet()) {
            User instructor = entry.getValue();
            List<String> titles = courseNamesByInstructor.getOrDefault(entry.getKey(), List.of());
            mentors.add(new MentorDTO(
                    instructor.getId(),
                    instructor.getName(),
                    instructor.getEmail(),
                    instructor.getPhone(),
                    "Course Mentor",
                    titles.isEmpty() ? "Mentor" : String.join(", ", titles),
                    false,
                    batch == null ? null : batch.getId(),
                    batch == null ? null : batch.getName(),
                    titles));
        }
        return mentors;
    }

    /**
     * The courses a student can access: explicit enrollments plus every course
     * unlocked by a plan they are subscribed to (the same rule the mobile app
     * uses to unlock courses, so the dashboard lists the faculty of exactly the
     * courses the student can open).
     *
     * <p>A student can hold more than one subscription at once, so access is the
     * union of <em>all</em> their ACTIVE plans plus the legacy single
     * {@code users.plan_id}. Matching only {@code user.getPlanId()} hid the
     * faculty of courses unlocked by a second subscription - e.g. a student with
     * both "Java Full Stack" and "Placement Pro" saw only the Placement faculty.
     */
    private List<Course> coursesFor(User user) {
        Map<Long, Course> byId = new LinkedHashMap<>();
        for (Enrollment enrollment : enrollmentRepository.findByUserId(user.getId())) {
            if (enrollment.getCourse() != null) byId.put(enrollment.getCourse().getId(), enrollment.getCourse());
        }
        Set<Long> planIds = activePlanIds(user);
        for (Course course : courseRepository.findAll()) {
            // An open course (no plan) is available to every student, matching how
            // the app unlocks courses; otherwise it must sit on one of the
            // student's active plans.
            if (course.getPlanId() == null || planIds.contains(course.getPlanId())) {
                byId.putIfAbsent(course.getId(), course);
            }
        }
        return new ArrayList<>(byId.values());
    }

    /**
     * Every plan id the student can currently access: the plans of all their
     * ACTIVE subscriptions, unioned with the legacy single {@code users.plan_id}.
     */
    private Set<Long> activePlanIds(User user) {
        Set<Long> planIds = new LinkedHashSet<>();
        if (user.getId() != null) {
            for (Subscription sub : subscriptionRepository.findByUserIdAndStatus(user.getId(), "ACTIVE")) {
                if (sub.getPlan() != null && sub.getPlan().getId() != null) {
                    planIds.add(sub.getPlan().getId());
                }
            }
        }
        if (user.getPlanId() != null) {
            planIds.add(user.getPlanId());
        }
        return planIds;
    }
}