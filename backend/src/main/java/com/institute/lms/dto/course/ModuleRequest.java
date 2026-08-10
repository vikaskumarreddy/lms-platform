package com.institute.lms.dto.course;

import java.util.List;

public class ModuleRequest {
    private String title;
    private String description;
    private Integer orderIndex;
    private String icon;
    private String color;
    private Boolean isLocked;
    private List<LessonRequest> lessons;

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }
    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }
    public Integer getOrderIndex() { return orderIndex; }
    public void setOrderIndex(Integer orderIndex) { this.orderIndex = orderIndex; }
    public String getIcon() { return icon; }
    public void setIcon(String icon) { this.icon = icon; }
    public String getColor() { return color; }
    public void setColor(String color) { this.color = color; }
    public Boolean getIsLocked() { return isLocked; }
    public void setIsLocked(Boolean isLocked) { this.isLocked = isLocked; }
    public List<LessonRequest> getLessons() { return lessons; }
    public void setLessons(List<LessonRequest> lessons) { this.lessons = lessons; }
}
