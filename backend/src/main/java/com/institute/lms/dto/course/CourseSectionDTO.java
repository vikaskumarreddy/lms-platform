package com.institute.lms.dto.course;

/**
 * Response DTO for a course section (module) as displayed on the mobile app
 * CourseDetailScreen. Includes progress (completedLessons) for the current user.
 */
public class CourseSectionDTO {
    private Long id;
    private String title;
    private String description;
    private String icon;
    private String color;
    private Integer orderIndex;
    private Boolean isLocked;
    private Integer totalLessons;
    private Integer completedLessons;

    public CourseSectionDTO() {}

    public CourseSectionDTO(Long id, String title, String description, String icon, String color,
                            Integer orderIndex, Boolean isLocked, Integer totalLessons, Integer completedLessons) {
        this.id = id;
        this.title = title;
        this.description = description;
        this.icon = icon;
        this.color = color;
        this.orderIndex = orderIndex;
        this.isLocked = isLocked;
        this.totalLessons = totalLessons;
        this.completedLessons = completedLessons;
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
    public Integer getTotalLessons() { return totalLessons; }
    public void setTotalLessons(Integer totalLessons) { this.totalLessons = totalLessons; }
    public Integer getCompletedLessons() { return completedLessons; }
    public void setCompletedLessons(Integer completedLessons) { this.completedLessons = completedLessons; }
}
