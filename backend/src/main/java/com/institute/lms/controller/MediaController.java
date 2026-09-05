package com.institute.lms.controller;

import com.institute.lms.entity.MediaItem;
import com.institute.lms.entity.User;
import com.institute.lms.exception.ResourceNotFoundException;
import com.institute.lms.repository.MediaItemRepository;
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

    public MediaController(MediaItemRepository repository, UserContext userContext) {
        this.repository = repository;
        this.userContext = userContext;
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
            store(item, bytes);
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
     * <p>Supports HTTP Range requests (206 Partial Content) — video elements in
     * WebViews issue a Range: bytes=0-1 probe before playing and then seek via
     * further ranged requests; without Accept-Ranges/Content-Range support the
     * WebView's media pipeline can refuse to play the file at all (observed as
     * a stuck 0:00 duration even though the byte response itself was a 200).
     */
    @GetMapping("/{id}/serve")
    public ResponseEntity<byte[]> serve(@PathVariable Long id, HttpServletRequest request) {
        MediaItem item = repository.findById(id).orElse(null);
        if (item == null) {
            return ResponseEntity.notFound().build();
        }
        byte[] bytes = readFromDisk(item);
        MediaType contentType;
        try {
            contentType = item.getMimeType() != null
                    ? MediaType.parseMediaType(item.getMimeType())
                    : MediaType.APPLICATION_OCTET_STREAM;
        } catch (Exception e) {
            // A browser-supplied Content-Type the parser rejects (e.g. with extra
            // codec params) must never turn into a 400/500 for what is otherwise
            // a perfectly servable file — fall back to a generic octet-stream type.
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

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        userContext.requireOrgAdminOrFaculty();
        MediaItem item = repository.findById(id).orElse(null);
        if (item != null) {
            repository.deleteById(id);
            deleteFromDisk(item.getFileName());
        }
        return ResponseEntity.ok().build();
    }

    // ------------------------------------------------------------------- disk

    private void store(MediaItem item, byte[] raw) throws IOException {
        byte[] gzipped = gzip(raw);
        String fileName = "media-" + System.currentTimeMillis() + "-"
                + UUID.randomUUID().toString().substring(0, 8) + ".bin.gz";
        Path dir = Paths.get(STORAGE_DIR);
        if (!Files.exists(dir)) Files.createDirectories(dir);
        Files.write(dir.resolve(fileName), gzipped);
        item.setFileName(fileName);
        item.setStoredSize((long) gzipped.length);
    }

    private byte[] readFromDisk(MediaItem item) {
        Path file = Paths.get(STORAGE_DIR, item.getFileName() == null ? "" : item.getFileName());
        if (item.getFileName() == null || !Files.exists(file)) {
            // The DB row survived (Postgres has its own volume) but the bytes on
            // disk did not — typically an uploads/ directory that was never
            // mounted as a persistent Docker volume, so a container
            // rebuild/restart wiped every uploaded file. A 404 here (not a bare
            // 500/400) lets the client show "this file is no longer available"
            // instead of a raw stack-trace-shaped error.
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

    private void deleteFromDisk(String fileName) {
        if (fileName == null) return;
        try {
            Files.deleteIfExists(Paths.get(STORAGE_DIR, fileName));
        } catch (IOException ignored) { }
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
        return m;
    }

    private String safeFileName(String title) {
        String safe = (title == null ? "media" : title).replaceAll("[^A-Za-z0-9-_ .]", "").trim();
        return safe.isEmpty() ? "media" : safe;
    }
}
