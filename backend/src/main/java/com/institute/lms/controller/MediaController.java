package com.institute.lms.controller;

import com.institute.lms.entity.MediaItem;
import com.institute.lms.entity.User;
import com.institute.lms.exception.ResourceNotFoundException;
import com.institute.lms.repository.MediaItemRepository;
import com.institute.lms.service.subscription.QuotaGuard;
import com.institute.lms.util.UserContext;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.Arrays;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;
import java.util.zip.GZIPInputStream;
import java.util.zip.GZIPOutputStream;

/**
 * "Media &amp; Files" hub storage: videos and files (PDF/image) uploaded through
 * the admin portal. Bytes are gzipped on disk (uploads/media) and served
 * through /api/media/{id}/serve; reused by Courses (lesson video/PDF) and
 * Company Questions (self-hosted PDF) instead of the old text-to-PDF
 * "Create PDF" generator. Mirrors PdfDocumentController's storage pattern.
 */
@RestController
@RequestMapping("/api/media")
public class MediaController {

    private static final String STORAGE_DIR = "uploads/media";

    /** Videos are capped smaller than generic files since they're the bulk of disk usage. */
    private static final long MAX_VIDEO_BYTES = 30L * 1024 * 1024;   // 30 MB
    private static final long MAX_FILE_BYTES = 60L * 1024 * 1024;    // 60 MB (PDF/image)

    private final MediaItemRepository repository;
    private final UserContext userContext;
    private final com.institute.lms.service.S3StorageService s3StorageService;
    private final QuotaGuard quotaGuard;

    public MediaController(MediaItemRepository repository,
                           UserContext userContext,
                           com.institute.lms.service.S3StorageService s3StorageService,
                           QuotaGuard quotaGuard) {
        this.repository = repository;
        this.userContext = userContext;
        this.s3StorageService = s3StorageService;
        this.quotaGuard = quotaGuard;
    }

    @GetMapping
    public List<Map<String, Object>> list(@RequestParam(value = "type", required = false) String type) {
        userContext.requireOrgAdminOrFaculty();
        List<MediaItem> items = (type == null || type.isBlank())
                ? repository.findAllByOrderByCreatedAtDesc()
                : repository.findAllByMediaTypeOrderByCreatedAtDesc(type);
        return items.stream().map(this::toMap).collect(Collectors.toList());
    }

    @GetMapping("/{id}")
    public ResponseEntity<Map<String, Object>> get(@PathVariable Long id) {
        userContext.requireOrgAdminOrFaculty();
        return repository.findById(id)
                .map(item -> ResponseEntity.ok(toMap(item)))
                .orElseGet(() -> ResponseEntity.notFound().build());
    }

    @PostMapping("/upload")
    public ResponseEntity<?> upload(@RequestParam("file") MultipartFile file,
                                    @RequestParam("type") String type,
                                    @RequestParam(value = "title", required = false) String title) {
        userContext.requireOrgAdminOrFaculty();

        if (file == null || file.isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of("error", "No file provided."));
        }

        Long academyId = userContext.currentUser() != null && userContext.currentUser().getOrganizationId() != null
                ? userContext.currentUser().getOrganizationId()
                : com.institute.lms.util.OrganizationContext.getCurrentOrgIdStatic();
        if (academyId != null) {
            quotaGuard.requireStorage(academyId, file.getSize());
        }

        String mediaType = "video".equalsIgnoreCase(type) ? "video" : "file";
        long maxBytes = "video".equals(mediaType) ? MAX_VIDEO_BYTES : MAX_FILE_BYTES;
        if (file.getSize() > maxBytes) {
            return ResponseEntity.status(HttpStatus.PAYLOAD_TOO_LARGE).body(Map.of(
                    "error", "video".equals(mediaType)
                            ? "Videos must be 30MB or smaller."
                            : "Files must be 60MB or smaller."
            ));
        }

        String name = file.getOriginalFilename() == null ? "upload" : file.getOriginalFilename();
        String cleanTitle = (title == null || title.isBlank())
                ? name.replaceAll("\\.[^.]+$", "")
                : title.trim();

        try {
            byte[] bytes = file.getBytes();
            MediaItem item = new MediaItem();
            item.setTitle(cleanTitle);
            item.setMediaType(mediaType);
            item.setMimeType(file.getContentType());
            item.setOriginalSize((long) bytes.length);
            User me = userContext.currentUser();
            item.setCreatedByUserId(me != null ? me.getId() : null);
            store(item, bytes, name);
            MediaItem saved = repository.save(item);
            return ResponseEntity.ok(Map.of("item", toMap(saved)));
        } catch (IOException e) {
            return ResponseEntity.internalServerError()
                    .body(Map.of("error", "Could not store the file: " + e.getMessage()));
        }
    }

    /**
     * Public (permitAll — see SecurityConfig) because <video src>/<img src>/
     * <iframe src> are plain browser GETs that cannot attach an Authorization
     * header; the request still resolves its tenant via the `token`/`tenant`
     * query params (see TenantInterceptor), so cross-tenant ids 404 correctly.
     *
     * <p>When stored in S3, redirects to an S3 presigned URL which natively
     * supports HTTP Range requests (206 Partial Content) for seeking.
     */
    @GetMapping("/{id}/serve")
    public ResponseEntity<?> serve(@PathVariable Long id, HttpServletRequest request) {
        MediaItem item = repository.findById(id).orElse(null);
        if (item == null) {
            return ResponseEntity.notFound().build();
        }

        if (s3StorageService.isConfigured() && item.getFileName() != null && item.getFileName().startsWith("academy/")) {
            String presignedUrl = s3StorageService.generatePresignedUrl(item.getFileName(), java.time.Duration.ofHours(2));
            if (presignedUrl != null) {
                return ResponseEntity.status(HttpStatus.FOUND)
                        .location(java.net.URI.create(presignedUrl))
                        .build();
            }
        }

        byte[] bytes = readFromDisk(item);
        MediaType contentType;
        try {
            contentType = item.getMimeType() != null
                    ? MediaType.parseMediaType(item.getMimeType())
                    : MediaType.APPLICATION_OCTET_STREAM;
        } catch (Exception e) {
            contentType = MediaType.APPLICATION_OCTET_STREAM;
        }

        String rangeHeader = request.getHeader(HttpHeaders.RANGE);
        int total = bytes.length;
        long start = 0;
        long end = total - 1;
        boolean isRange = rangeHeader != null && rangeHeader.startsWith("bytes=");
        if (isRange) {
            String spec = rangeHeader.substring("bytes=".length()).split(",")[0].trim();
            String[] parts = spec.split("-", -1);
            try {
                if (!parts[0].isEmpty()) start = Long.parseLong(parts[0]);
                if (parts.length > 1 && !parts[1].isEmpty()) end = Long.parseLong(parts[1]);
                else end = total - 1;
                if (start > end || end >= total) {
                    return ResponseEntity.status(HttpStatus.REQUESTED_RANGE_NOT_SATISFIABLE)
                            .header(HttpHeaders.CONTENT_RANGE, "bytes */" + total)
                            .build();
                }
            } catch (NumberFormatException e) {
                isRange = false;
                start = 0;
                end = total - 1;
            }
        }

        byte[] body = (isRange || start > 0 || end < total - 1)
                ? Arrays.copyOfRange(bytes, (int) start, (int) end + 1)
                : bytes;

        ResponseEntity.BodyBuilder builder = isRange
                ? ResponseEntity.status(HttpStatus.PARTIAL_CONTENT)
                        .header(HttpHeaders.CONTENT_RANGE, "bytes " + start + "-" + end + "/" + total)
                : ResponseEntity.ok();

        return builder
                .header(HttpHeaders.CONTENT_TYPE, contentType.toString())
                .header(HttpHeaders.CONTENT_DISPOSITION, "inline; filename=\"" + safeFileName(item.getTitle()) + "\"")
                .header(HttpHeaders.CACHE_CONTROL, "private, max-age=3600")
                .header(HttpHeaders.ACCEPT_RANGES, "bytes")
                .header(HttpHeaders.CONTENT_LENGTH, String.valueOf(body.length))
                .body(body);
    }

    /**
     * Serves an arbitrary S3 key via 302 redirect to a presigned URL.
     */
    @GetMapping("/serve-key")
    public ResponseEntity<?> serveKey(@RequestParam("key") String key) {
        if (s3StorageService.isConfigured() && key != null && !key.isBlank()) {
            String presignedUrl = s3StorageService.generatePresignedUrl(key, java.time.Duration.ofHours(2));
            if (presignedUrl != null) {
                return ResponseEntity.status(HttpStatus.FOUND)
                        .location(java.net.URI.create(presignedUrl))
                        .build();
            }
        }
        return ResponseEntity.notFound().build();
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        userContext.requireOrgAdminOrFaculty();
        MediaItem item = repository.findById(id).orElse(null);
        if (item != null) {
            repository.deleteById(id);
            deleteMedia(item.getFileName());
        }
        return ResponseEntity.ok().build();
    }

    // ------------------------------------------------------------------- storage

    private void store(MediaItem item, byte[] raw, String originalName) throws IOException {
        Long academyId = userContext.currentUser() != null && userContext.currentUser().getOrganizationId() != null
                ? userContext.currentUser().getOrganizationId()
                : com.institute.lms.util.OrganizationContext.getCurrentOrgIdStatic();

        String extension = "";
        if (originalName != null && originalName.contains(".")) {
            extension = originalName.substring(originalName.lastIndexOf('.'));
        } else if ("video".equalsIgnoreCase(item.getMediaType())) {
            extension = ".mp4";
        } else if (item.getMimeType() != null && item.getMimeType().contains("pdf")) {
            extension = ".pdf";
        }

        String fileName = "media-" + System.currentTimeMillis() + "-"
                + UUID.randomUUID().toString().substring(0, 8) + extension;
        String category = s3StorageService.normalizeCategory(item.getMediaType(), originalName);

        if (s3StorageService.isConfigured()) {
            String s3Key = s3StorageService.buildKey(academyId, category, fileName);
            s3StorageService.upload(s3Key, raw, item.getMimeType());
            item.setFileName(s3Key);
            item.setStoredSize((long) raw.length);
        } else {
            byte[] gzipped = gzip(raw);
            String localFileName = fileName + ".bin.gz";
            Path dir = Paths.get(STORAGE_DIR);
            if (!Files.exists(dir)) Files.createDirectories(dir);
            Files.write(dir.resolve(localFileName), gzipped);
            item.setFileName(localFileName);
            item.setStoredSize((long) gzipped.length);
        }
    }

    private byte[] readFromDisk(MediaItem item) {
        if (item.getFileName() == null || item.getFileName().isBlank()) {
            throw ResourceNotFoundException.of("Media file", item.getId());
        }
        if (s3StorageService.isConfigured() && item.getFileName().startsWith("academy/")) {
            try {
                return s3StorageService.download(item.getFileName());
            } catch (Exception e) {
                throw new RuntimeException("Could not read media file from S3: " + item.getFileName(), e);
            }
        }
        Path file = Paths.get(STORAGE_DIR, item.getFileName());
        if (!Files.exists(file)) {
            throw ResourceNotFoundException.of("Media file", item.getId());
        }
        try {
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            try (InputStream in = new GZIPInputStream(new ByteArrayInputStream(Files.readAllBytes(file)))) {
                in.transferTo(out);
            }
            return out.toByteArray();
        } catch (IOException e) {
            throw new RuntimeException("Could not read media file for item " + item.getId(), e);
        }
    }

    private void deleteMedia(String fileName) {
        if (fileName == null || fileName.isBlank()) return;
        if (s3StorageService.isConfigured() && fileName.startsWith("academy/")) {
            s3StorageService.delete(fileName);
        } else {
            try {
                Files.deleteIfExists(Paths.get(STORAGE_DIR, fileName));
            } catch (IOException ignored) { }
        }
    }

    private byte[] gzip(byte[] data) throws IOException {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        try (GZIPOutputStream gz = new GZIPOutputStream(out)) {
            gz.write(data);
        }
        return out.toByteArray();
    }

    // ------------------------------------------------------------------- maps

    private Map<String, Object> toMap(MediaItem item) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", item.getId());
        m.put("title", item.getTitle());
        m.put("type", item.getMediaType());
        m.put("mimeType", item.getMimeType());
        m.put("originalSize", item.getOriginalSize());
        m.put("storedSize", item.getStoredSize());
        m.put("duration", item.getDurationSeconds());
        m.put("width", item.getWidth());
        m.put("height", item.getHeight());
        m.put("createdByName", item.getCreatedBy());
        m.put("createdAt", item.getCreatedAt());
        m.put("s3Key", item.getFileName());
        if (s3StorageService.isConfigured() && item.getFileName() != null && item.getFileName().startsWith("academy/")) {
            m.put("url", s3StorageService.generatePresignedUrl(item.getFileName(), java.time.Duration.ofHours(24)));
        } else {
            m.put("url", "/api/media/" + item.getId() + "/serve");
        }
        return m;
    }

    private String safeFileName(String title) {
        String safe = (title == null ? "media" : title).replaceAll("[^A-Za-z0-9-_ .]", "").trim();
        return safe.isEmpty() ? "media" : safe;
    }
}
