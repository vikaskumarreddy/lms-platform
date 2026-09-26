package com.institute.lms.controller;

import com.institute.lms.entity.PdfDocument;
import com.institute.lms.entity.User;
import com.institute.lms.repository.PdfDocumentRepository;
import com.institute.lms.service.S3StorageService;
import com.institute.lms.util.UserContext;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

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
 * Storage for the admin portal "PDF Tools" editor: uploaded PDFs are kept
 * gzipped on disk (uploads/pdf-documents) and served through
 * /api/pdf-documents/{id}/file. Saving an edited document replaces the stored
 * bytes; annotations/overlays are burned into the bytes client-side (pdf-lib)
 * so the server stays a dumb, compressed blob store.
 */
@RestController
@RequestMapping("/api/pdf-documents")
public class PdfDocumentController {

    private static final String STORAGE_DIR = "uploads/pdf-documents";

    private final PdfDocumentRepository repository;
    private final UserContext userContext;
    private final S3StorageService s3StorageService;
    private final com.institute.lms.service.subscription.QuotaGuard quotaGuard;

    public PdfDocumentController(PdfDocumentRepository repository,
                                 UserContext userContext,
                                 S3StorageService s3StorageService,
                                 com.institute.lms.service.subscription.QuotaGuard quotaGuard) {
        this.repository = repository;
        this.userContext = userContext;
        this.s3StorageService = s3StorageService;
        this.quotaGuard = quotaGuard;
    }

    @GetMapping
    public List<Map<String, Object>> list() {
        userContext.requireOrgAdminOrFaculty();
        return repository.findAllByOrderByCreatedAtDesc().stream()
                .map(this::toMap)
                .collect(Collectors.toList());
    }

    @PostMapping("/upload")
    public ResponseEntity<?> upload(@RequestParam("file") MultipartFile file,
                                    @RequestParam(value = "title", required = false) String title,
                                    @RequestParam(value = "pageCount", required = false) Integer pageCount) {
        userContext.requireOrgAdminOrFaculty();
        if (file == null || file.isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of("error", "No PDF file provided."));
        }

        Long academyId = userContext.currentUser() != null && userContext.currentUser().getOrganizationId() != null
                ? userContext.currentUser().getOrganizationId()
                : com.institute.lms.util.OrganizationContext.getCurrentOrgIdStatic();
        if (academyId != null) {
            quotaGuard.requireStorage(academyId, file.getSize());
        }

        String name = file.getOriginalFilename() == null ? "document.pdf" : file.getOriginalFilename();
        String cleanTitle = (title == null || title.isBlank())
                ? name.replaceAll("(?i)\\.pdf$", "")
                : title.trim();
        try {
            byte[] bytes = file.getBytes();
            PdfDocument doc = new PdfDocument();
            doc.setTitle(cleanTitle);
            doc.setPageCount(pageCount);
            doc.setOriginalSize((long) bytes.length);
            User me = userContext.currentUser();
            doc.setCreatedByUserId(me != null ? me.getId() : null);
            store(doc, bytes);
            return ResponseEntity.ok(toMap(repository.save(doc)));
        } catch (IOException e) {
            return ResponseEntity.internalServerError()
                    .body(Map.of("error", "Could not store the PDF: " + e.getMessage()));
        }
    }

    /** Replaces the stored bytes after the editor exports an edited copy. */
    @PutMapping("/{id}")
    public ResponseEntity<?> replace(@PathVariable Long id,
                                     @RequestParam("file") MultipartFile file,
                                     @RequestParam(value = "pageCount", required = false) Integer pageCount) {
        userContext.requireOrgAdminOrFaculty();
        PdfDocument doc = repository.findById(id).orElse(null);
        if (doc == null) return ResponseEntity.notFound().build();
        if (file == null || file.isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of("error", "No PDF file provided."));
        }
        try {
            byte[] bytes = file.getBytes();
            doc.setOriginalSize((long) bytes.length);
            if (pageCount != null) doc.setPageCount(pageCount);
            store(doc, bytes);
            return ResponseEntity.ok(toMap(repository.save(doc)));
        } catch (IOException e) {
            return ResponseEntity.internalServerError()
                    .body(Map.of("error", "Could not store the PDF: " + e.getMessage()));
        }
    }

    @GetMapping("/{id}/file")
    public ResponseEntity<?> file(@PathVariable Long id) {
        userContext.requireOrgAdminOrFaculty();
        PdfDocument doc = repository.findById(id)
                .orElseThrow(() -> new RuntimeException("PDF document not found"));
        if (s3StorageService.isConfigured() && doc.getFileName() != null && doc.getFileName().startsWith("academy/")) {
            String presigned = s3StorageService.generatePresignedUrl(doc.getFileName(), java.time.Duration.ofHours(2));
            if (presigned != null) {
                return ResponseEntity.status(org.springframework.http.HttpStatus.FOUND)
                        .location(java.net.URI.create(presigned))
                        .build();
            }
        }
        byte[] pdf = readFromDisk(doc);
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_PDF_VALUE)
                .header(HttpHeaders.CONTENT_DISPOSITION,
                        "inline; filename=\"" + safeFileName(doc.getTitle()) + ".pdf\"")
                .body(pdf);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        userContext.requireOrgAdminOrFaculty();
        PdfDocument doc = repository.findById(id).orElse(null);
        if (doc != null) {
            repository.deleteById(id);
            if (s3StorageService.isConfigured() && doc.getFileName() != null && doc.getFileName().startsWith("academy/")) {
                s3StorageService.delete(doc.getFileName());
            } else {
                deleteFromDisk(doc.getFileName());
            }
        }
        return ResponseEntity.ok().build();
    }

    // ------------------------------------------------------------------- disk

    private void store(PdfDocument doc, byte[] pdf) throws IOException {
        Long academyId = userContext.currentUser() != null && userContext.currentUser().getOrganizationId() != null
                ? userContext.currentUser().getOrganizationId()
                : com.institute.lms.util.OrganizationContext.getCurrentOrgIdStatic();

        if (s3StorageService.isConfigured()) {
            String fileName = "doc-" + System.currentTimeMillis() + "-"
                    + UUID.randomUUID().toString().substring(0, 8) + ".pdf";
            String s3Key = s3StorageService.buildKey(academyId, "pdf", fileName);
            s3StorageService.upload(s3Key, pdf, "application/pdf");
            if (doc.getFileName() != null && doc.getFileName().startsWith("academy/")) {
                s3StorageService.delete(doc.getFileName());
            }
            doc.setFileName(s3Key);
            doc.setStoredSize((long) pdf.length);
        } else {
            byte[] gzipped = gzip(pdf);
            String fileName = "doc-" + System.currentTimeMillis() + "-"
                    + UUID.randomUUID().toString().substring(0, 8) + ".pdf.gz";
            Path dir = Paths.get(STORAGE_DIR);
            if (!Files.exists(dir)) Files.createDirectories(dir);
            Files.write(dir.resolve(fileName), gzipped);
            if (doc.getFileName() != null) deleteFromDisk(doc.getFileName());
            doc.setFileName(fileName);
            doc.setStoredSize((long) gzipped.length);
        }
    }

    private byte[] readFromDisk(PdfDocument doc) {
        if (doc.getFileName() == null || doc.getFileName().isBlank()) {
            throw new RuntimeException("PDF file is missing for document " + doc.getId());
        }
        if (s3StorageService.isConfigured() && doc.getFileName().startsWith("academy/")) {
            try {
                return s3StorageService.download(doc.getFileName());
            } catch (Exception e) {
                throw new RuntimeException("Could not read PDF from S3 for document " + doc.getId(), e);
            }
        }
        try {
            Path file = Paths.get(STORAGE_DIR, doc.getFileName());
            if (!Files.exists(file)) {
                throw new RuntimeException("PDF file is missing for document " + doc.getId());
            }
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            try (InputStream in = new GZIPInputStream(new ByteArrayInputStream(Files.readAllBytes(file)))) {
                in.transferTo(out);
            }
            return out.toByteArray();
        } catch (IOException e) {
            throw new RuntimeException("Could not read PDF file for document " + doc.getId(), e);
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

    private Map<String, Object> toMap(PdfDocument doc) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", doc.getId());
        m.put("title", doc.getTitle());
        m.put("pageCount", doc.getPageCount());
        m.put("originalSize", doc.getOriginalSize());
        m.put("storedSize", doc.getStoredSize());
        m.put("createdByName", doc.getCreatedBy());
        m.put("createdAt", doc.getCreatedAt());
        return m;
    }

    private String safeFileName(String title) {
        String safe = (title == null ? "document" : title).replaceAll("[^A-Za-z0-9-_ ]", "").trim();
        return safe.isEmpty() ? "document" : safe;
    }
}

