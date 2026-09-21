package com.institute.lms.dto.dashboard;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

/**
 * A mentor a student can see on the dashboard, with enough context to explain
 * <em>why</em> they are that student's mentor (their batch's mentor, or the
 * instructor of a course on their plan).
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class MentorDTO {

    private Long id;
    private String name;
    private String email;
    private String phone;

    /** Human-readable role label shown under the name, e.g. "Batch Mentor". */
    private String designation;

    /** What they teach / mentor on, e.g. the batch name or the course titles. */
    private String expertise;

    /** True for the student's own batch mentor (rendered first, as the primary contact). */
    private boolean primaryMentor;

    private Long batchId;
    private String batchName;

    /** Courses this mentor owns that are relevant to the student. */
    private List<String> courseNames;
}