package com.institute.lms.dto.course;

/**
 * Response DTO for a lesson as displayed on the mobile app.
 * Includes user-specific `completed` status derived from the progress table.
 */
public class LessonProgressDTO {
    private Long id;
    private String title;
    private String heading;
    private String content;
    private String videoUrl;
    /** "URL" (external, e.g. YouTube) or "SELF" (uploaded MediaItem) — tells the
     *  mobile app whether to embed a YouTube iframe or play videoUrl natively. */
    private String videoSource;
    private Integer durationMinutes;
    private Integer orderIndex;
    private Boolean isLocked;
    private Boolean isMandatory;
    private String thumbnailUrl;
    private String pdfNotesUrl;
    private Boolean completed;

    public LessonProgressDTO() {}

    public LessonProgressDTO(Long id, String title, String heading, String content, String videoUrl,
                             Integer durationMinutes, Integer orderIndex, Boolean isLocked,
                             Boolean isMandatory, String thumbnailUrl, String pdfNotesUrl, Boolean completed) {
        this(id, title, heading, content, videoUrl, "URL", durationMinutes, orderIndex, isLocked,
                isMandatory, thumbnailUrl, pdfNotesUrl, completed);
    }

    public LessonProgressDTO(Long id, String title, String heading, String content, String videoUrl,
                             String videoSource, Integer durationMinutes, Integer orderIndex, Boolean isLocked,
                             Boolean isMandatory, String thumbnailUrl, String pdfNotesUrl, Boolean completed) {
        this.id = id;
        this.title = title;
        this.heading = heading;
        this.content = content;
        this.videoUrl = videoUrl;
        this.videoSource = videoSource;
        this.durationMinutes = durationMinutes;
        this.orderIndex = orderIndex;
        this.isLocked = isLocked;
        this.isMandatory = isMandatory;
        this.thumbnailUrl = thumbnailUrl;
        this.pdfNotesUrl = pdfNotesUrl;
        this.completed = completed;
    }

    // Getters and setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }
    public String getHeading() { return heading; }
    public void setHeading(String heading) { this.heading = heading; }
    public String getContent() { return content; }
    public void setContent(String content) { this.content = content; }
    public String getVideoUrl() { return videoUrl; }
    public void setVideoUrl(String videoUrl) { this.videoUrl = videoUrl; }
    public String getVideoSource() { return videoSource; }
    public void setVideoSource(String videoSource) { this.videoSource = videoSource; }
    public Integer getDurationMinutes() { return durationMinutes; }
    public void setDurationMinutes(Integer durationMinutes) { this.durationMinutes = durationMinutes; }
    public Integer getOrderIndex() { return orderIndex; }
    public void setOrderIndex(Integer orderIndex) { this.orderIndex = orderIndex; }
    public Boolean getIsLocked() { return isLocked; }
    public void setIsLocked(Boolean isLocked) { this.isLocked = isLocked; }
    public Boolean getIsMandatory() { return isMandatory; }
    public void setIsMandatory(Boolean isMandatory) { this.isMandatory = isMandatory; }
    public String getThumbnailUrl() { return thumbnailUrl; }
    public void setThumbnailUrl(String thumbnailUrl) { this.thumbnailUrl = thumbnailUrl; }
    public String getPdfNotesUrl() { return pdfNotesUrl; }
    public void setPdfNotesUrl(String pdfNotesUrl) { this.pdfNotesUrl = pdfNotesUrl; }
    public Boolean getCompleted() { return completed; }
    public void setCompleted(Boolean completed) { this.completed = completed; }
}
