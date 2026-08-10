package com.institute.lms.dto.course;

public class LessonRequest {
    private String title;
    private String heading;
    private String content;
    private String videoUrl;
    private String thumbnailUrl;
    private String pdfNotesUrl;
    private Integer orderIndex;
    private Integer durationMinutes;
    private Boolean isLocked;
    private Boolean isMandatory;

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }
    public String getHeading() { return heading; }
    public void setHeading(String heading) { this.heading = heading; }
    public String getContent() { return content; }
    public void setContent(String content) { this.content = content; }
    public String getVideoUrl() { return videoUrl; }
    public void setVideoUrl(String videoUrl) { this.videoUrl = videoUrl; }
    public String getThumbnailUrl() { return thumbnailUrl; }
    public void setThumbnailUrl(String thumbnailUrl) { this.thumbnailUrl = thumbnailUrl; }
    public String getPdfNotesUrl() { return pdfNotesUrl; }
    public void setPdfNotesUrl(String pdfNotesUrl) { this.pdfNotesUrl = pdfNotesUrl; }
    public Integer getOrderIndex() { return orderIndex; }
    public void setOrderIndex(Integer orderIndex) { this.orderIndex = orderIndex; }
    public Integer getDurationMinutes() { return durationMinutes; }
    public void setDurationMinutes(Integer durationMinutes) { this.durationMinutes = durationMinutes; }
    public Boolean getIsLocked() { return isLocked; }
    public void setIsLocked(Boolean isLocked) { this.isLocked = isLocked; }
    public Boolean getIsMandatory() { return isMandatory; }
    public void setIsMandatory(Boolean isMandatory) { this.isMandatory = isMandatory; }
}
