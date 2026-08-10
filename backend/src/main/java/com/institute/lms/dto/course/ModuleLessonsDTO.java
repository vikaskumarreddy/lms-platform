package com.institute.lms.dto.course;

import java.util.List;

/**
 * Response DTO for a module (section) with its lessons, as displayed on the mobile app
 * CourseSectionLessonsScreen. Includes user-specific `completed` status on each lesson.
 */
public class ModuleLessonsDTO {
    private Long id;
    private String title;
    private String description;
    private String icon;
    private String color;
    private Integer orderIndex;
    private Boolean isLocked;
    private List<LessonProgressDTO> lessons;

    public ModuleLessonsDTO() {}

    public ModuleLessonsDTO(Long id, String title, String description, String icon, String color,
                            Integer orderIndex, Boolean isLocked, List<LessonProgressDTO> lessons) {
        this.id = id;
        this.title = title;
        this.description = description;
        this.icon = icon;
        this.color = color;
        this.orderIndex = orderIndex;
        this.isLocked = isLocked;
        this.lessons = lessons;
    }

    // Getters and setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }
    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }
    public String getIcon() { return icon; }
    public void setIcon(String icon) { this.icon = icon; }
    public String getColor() { return color; }
    public void setColor(String color) { this.color = color; }
    public Integer getOrderIndex() { return orderIndex; }
    public void setOrderIndex(Integer orderIndex) { this.orderIndex = orderIndex; }
    public Boolean getIsLocked() { return isLocked; }
    public void setIsLocked(Boolean isLocked) { this.isLocked = isLocked; }
    public List<LessonProgressDTO> getLessons() { return lessons; }
    public void setLessons(List<LessonProgressDTO> lessons) { this.lessons = lessons; }
}
