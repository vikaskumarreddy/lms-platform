package com.institute.lms.dto.course;

import java.util.List;

public class CourseRequest {
    private String title;
    private String description;
    private String thumbnailUrl;
    private Long instructorId;
    private Long planId;
    private Boolean isPublished;
    private List<ModuleRequest> modules;

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }
    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }
    public String getThumbnailUrl() { return thumbnailUrl; }
    public void setThumbnailUrl(String thumbnailUrl) { this.thumbnailUrl = thumbnailUrl; }
    public Long getInstructorId() { return instructorId; }
    public void setInstructorId(Long instructorId) { this.instructorId = instructorId; }
    public Long getPlanId() { return planId; }
    public void setPlanId(Long planId) { this.planId = planId; }
    public Boolean getIsPublished() { return isPublished; }
    public void setIsPublished(Boolean isPublished) { this.isPublished = isPublished; }
    public List<ModuleRequest> getModules() { return modules; }
    public void setModules(List<ModuleRequest> modules) { this.modules = modules; }
}