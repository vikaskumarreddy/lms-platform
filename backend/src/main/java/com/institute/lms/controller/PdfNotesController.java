package com.institute.lms.controller;

import com.institute.lms.entity.PdfNote;
import com.institute.lms.entity.User;
import com.institute.lms.repository.PdfNoteRepository;
import com.institute.lms.repository.UserRepository;
import com.institute.lms.service.S3StorageService;
import com.institute.lms.util.UserContext;
import jakarta.servlet.http.HttpServletRequest;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.pdmodel.PDPage;
import org.apache.pdfbox.pdmodel.PDPageContentStream;
import org.apache.pdfbox.pdmodel.common.PDRectangle;
import org.apache.pdfbox.pdmodel.font.PDFont;
import org.apache.pdfbox.pdmodel.font.PDType1Font;
import org.apache.pdfbox.pdmodel.font.Standard14Fonts;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.awt.Color;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;
import java.util.zip.GZIPInputStream;
import java.util.zip.GZIPOutputStream;

/** Faculty "Create PDF" notes. Rendered into a styled, compressed PDF, stored
 *  gzipped on disk, served decompressed through /api/pdf-notes/{id}/file. */
@RestController
@RequestMapping("/api/pdf-notes")
public class PdfNotesController {

    private static final org.slf4j.Logger log = org.slf4j.LoggerFactory.getLogger(PdfNotesController.class);

    private static final String STORAGE_DIR = "uploads/pdf-notes";
    private static final Color NAVY = new Color(0x0F172A);
    private static final Color GOLD = new Color(0xEAB308);
    /** PDFBox 3.x: standard-14 fonts are instances built from Standard14Fonts names. */
    private static final PDFont FONT_BODY = new PDType1Font(Standard14Fonts.FontName.HELVETICA);
    private static final PDFont FONT_TITLE = new PDType1Font(Standard14Fonts.FontName.HELVETICA_BOLD);

    private final PdfNoteRepository pdfNoteRepository;
    private final UserRepository userRepository;
    private final UserContext userContext;
    private final S3StorageService s3StorageService;

    public PdfNotesController(PdfNoteRepository pdfNoteRepository,
                              UserRepository userRepository,
                              UserContext userContext,
                              S3StorageService s3StorageService) {
        this.pdfNoteRepository = pdfNoteRepository;
        this.userRepository = userRepository;
        this.userContext = userContext;
        this.s3StorageService = s3StorageService;
    }

    @GetMapping
    public List<Map<String, Object>> list(HttpServletRequest request) {
        userContext.requireOrgAdminOrFaculty();
        return pdfNoteRepository.findAllByOrderByCreatedAtDesc().stream()
                .map(note -> toMap(note, request))
                .collect(Collectors.toList());
    }

    @GetMapping("/{id}")
    public ResponseEntity<Map<String, Object>> get(@PathVariable Long id, HttpServletRequest request) {
        return pdfNoteRepository.findById(id)
                .map(note -> ResponseEntity.ok(toMap(note, request)))
                .orElseGet(() -> ResponseEntity.notFound().build());
    }

    @GetMapping("/{id}/file")
    public ResponseEntity<?> file(@PathVariable Long id) {
        PdfNote note = pdfNoteRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("PDF note not found"));
        if (s3StorageService.isConfigured() && note.getFileName() != null && note.getFileName().startsWith("academy/")) {
            String presigned = s3StorageService.generatePresignedUrl(note.getFileName(), java.time.Duration.ofHours(2));
            if (presigned != null) {
                return ResponseEntity.status(org.springframework.http.HttpStatus.FOUND)
                        .location(java.net.URI.create(presigned))
                        .build();
            }
        }
        byte[] pdf = readPdfFromDisk(note);
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_PDF_VALUE)
                .header(HttpHeaders.CONTENT_DISPOSITION,
                        "inline; filename=\"" + safeFileName(note.getTitle()) + ".pdf\"")
                .body(pdf);
    }

    @PostMapping
    public ResponseEntity<?> create(@RequestBody Map<String, Object> body, HttpServletRequest request) {
        userContext.requireOrgAdminOrFaculty();
        String title = body.get("title") == null ? "" : String.valueOf(body.get("title")).trim();
        String content = body.get("content") == null ? "" : String.valueOf(body.get("content"));
        if (title.isEmpty()) return ResponseEntity.badRequest().body(Map.of("error", "Title is required."));
        if (content.isBlank()) return ResponseEntity.badRequest().body(Map.of("error", "Content is required."));
        try {
            byte[] pdfBytes = renderPdf(title, content);
            PdfNote note = new PdfNote();
            note.setTitle(title);
            note.setContent(content);
            User me = userContext.currentUser();
            note.setCreatedByUserId(me != null ? me.getId() : null);
            note.setOriginalSize((long) pdfBytes.length);

            Long academyId = me != null && me.getOrganizationId() != null
                    ? me.getOrganizationId()
                    : com.institute.lms.util.OrganizationContext.getCurrentOrgIdStatic();

            boolean uploadedToS3 = false;
            if (s3StorageService.isConfigured()) {
                try {
                    String fileName = "pdf-" + System.currentTimeMillis() + "-"
                            + UUID.randomUUID().toString().substring(0, 8) + ".pdf";
                    String s3Key = s3StorageService.buildKey(academyId, "pdf", fileName);
                    s3StorageService.upload(s3Key, pdfBytes, "application/pdf");
                    note.setFileName(s3Key);
                    note.setStoredSize((long) pdfBytes.length);
                    uploadedToS3 = true;
                } catch (Exception e) {
                    log.warn("S3 upload failed for PDF note ({}), falling back to local storage.", e.getMessage());
                }
            }
            if (!uploadedToS3) {
                byte[] gzipped = gzip(pdfBytes);
                String fileName = "pdf-" + System.currentTimeMillis() + "-"
                        + UUID.randomUUID().toString().substring(0, 8) + ".pdf.gz";
                writePdfToDisk(fileName, gzipped);
                note.setFileName(fileName);
                note.setStoredSize((long) gzipped.length);
            }
            return ResponseEntity.ok(toMap(pdfNoteRepository.save(note), request));
        } catch (IOException e) {
            return ResponseEntity.internalServerError()
                    .body(Map.of("error", "Could not generate PDF: " + e.getMessage()));
        }
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        userContext.requireOrgAdminOrFaculty();
        PdfNote note = pdfNoteRepository.findById(id).orElse(null);
        if (note != null) {
            pdfNoteRepository.deleteById(id);
            if (s3StorageService.isConfigured() && note.getFileName() != null && note.getFileName().startsWith("academy/")) {
                s3StorageService.delete(note.getFileName());
            } else {
                deleteFileFromDisk(note.getFileName());
            }
        }
        return ResponseEntity.ok().build();
    }
    // ------------------------------------------------------------------- render

    byte[] renderPdf(String title, String content) throws IOException {
        try (PDDocument doc = new PDDocument()) {
            doc.setVersion(1.7f);
            float width = PDRectangle.A4.getWidth();
            float height = PDRectangle.A4.getHeight();
            float margin = 50f;
            float maxTextWidth = width - 2 * margin;
            float lineHeight = 15f;

            PDPage page = new PDPage(PDRectangle.A4);
            doc.addPage(page);
            PDPageContentStream cs = new PDPageContentStream(doc, page,
                    PDPageContentStream.AppendMode.APPEND, true, true);
            try {
                paintBanner(cs, width, height);
                paintTitle(cs, title, margin, height, maxTextWidth);
                paintGoldRule(cs, margin, width, height - 48);

                float y = height - 70;
                boolean firstBlock = true;
                for (String block : content.split("\\n\\n")) {
                    block = block.trim();
                    if (block.isEmpty()) continue;
                    if (!firstBlock) y -= 8;
                    firstBlock = false;

                    for (String rawLine : block.split("\\n")) {
                        String line = rawLine.trim();
                        if (line.isEmpty()) { y -= 6; continue; }
                        boolean bullet = line.startsWith("- ") || line.startsWith("* ");
                        String text = bullet ? line.substring(2) : line;

                        for (String wrapped : wrapText(text, FONT_BODY, 11.5f,
                                maxTextWidth - (bullet ? 14 : 0))) {
                            if (y < 46) {
                                cs = startNewPage(doc, cs, width, height);
                                y = height - 58;
                            }
                            drawBodyLine(cs, margin, y - 2, wrapped, bullet);
                            y -= lineHeight;
                        }
                    }
                }
            } finally {
                cs.close();
            }

            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            doc.save(baos);
            return baos.toByteArray();
        }
    }
    // ---------------------------------------------------------- rendering helpers

    private void paintBanner(PDPageContentStream cs, float width, float height) throws IOException {
        cs.addRect(0, height - 12, width, 12);
        cs.setNonStrokingColor(NAVY);
        cs.fill();
    }

    private void paintTitle(PDPageContentStream cs, String title, float margin, float height,
                            float maxWidth) throws IOException {
        cs.setNonStrokingColor(NAVY);
        cs.beginText();
        cs.setFont(FONT_TITLE, 18);
        cs.newLineAtOffset(margin, height - 40);
        for (String line : wrapText(title, FONT_TITLE, 18, maxWidth)) {
            cs.showText(stripControl(line));
            cs.newLineAtOffset(0, -22);
        }
        cs.endText();
    }

    private void paintGoldRule(PDPageContentStream cs, float margin, float width, float y) throws IOException {
        cs.setStrokingColor(GOLD);
        cs.setLineWidth(2.5f);
        cs.moveTo(margin, y);
        cs.lineTo(width - margin, y);
        cs.stroke();
    }

    private void drawBodyLine(PDPageContentStream cs, float margin, float y, String text, boolean bullet)
            throws IOException {
        if (bullet) {
            cs.setNonStrokingColor(GOLD);
            cs.beginText();
            cs.setFont(FONT_BODY, 11.5f);
            cs.newLineAtOffset(margin, y);
            cs.showText("\u2022 ");
            cs.endText();
        }
        cs.setNonStrokingColor(new Color(0x334155));
        cs.beginText();
        cs.setFont(FONT_BODY, 11.5f);
        cs.newLineAtOffset(margin + (bullet ? 14 : 0), y);
        cs.showText(stripControl(text));
        cs.endText();
    }

    private PDPageContentStream startNewPage(PDDocument doc, PDPageContentStream old,
                                             float width, float height) throws IOException {
        old.close();
        PDPage newPage = new PDPage(PDRectangle.A4);
        doc.addPage(newPage);
        PDPageContentStream cs = new PDPageContentStream(doc, newPage,
                PDPageContentStream.AppendMode.APPEND, true, true);
        paintBanner(cs, width, height);
        return cs;
    }

    private String stripControl(String s) {
        StringBuilder sb = new StringBuilder(s.length());
        for (char c : s.toCharArray()) {
            if (c == '\n' || c == '\r' || c == '\t') continue;
            sb.append(c);
        }
        return sb.toString();
    }

    private List<String> wrapText(String text, PDFont font, float fontSize, float maxWidth) {
        List<String> lines = new ArrayList<>();
        if (text == null || text.isEmpty()) { lines.add(""); return lines; }
        StringBuilder current = new StringBuilder();
        float currentWidth = 0;
        for (String word : text.split(" ")) {
            float wordWidth = stringWidth(font, fontSize, word + " ");
            if (current.length() > 0 && currentWidth + wordWidth > maxWidth) {
                lines.add(current.toString().trim());
                current.setLength(0);
                currentWidth = 0;
            }
            current.append(word).append(' ');
            currentWidth += wordWidth;
        }
        if (current.length() > 0) lines.add(current.toString().trim());
        return lines;
    }

    private float stringWidth(PDFont font, float fontSize, String text) {
        try {
            return font.getStringWidth(text) / 1000f * fontSize;
        } catch (Exception e) {
            return text.length() * fontSize * 0.5f;
        }
    }
    // ------------------------------------------------------------------- disk

    private void writePdfToDisk(String fileName, byte[] bytes) throws IOException {
        Path uploadPath = Paths.get(STORAGE_DIR);
        if (!Files.exists(uploadPath)) Files.createDirectories(uploadPath);
        Files.write(uploadPath.resolve(fileName), bytes);
    }

    private byte[] readPdfFromDisk(PdfNote note) {
        if (note.getFileName() == null || note.getFileName().isBlank()) {
            throw new RuntimeException("PDF file is missing for note " + note.getId());
        }
        if (s3StorageService.isConfigured() && note.getFileName().startsWith("academy/")) {
            try {
                return s3StorageService.download(note.getFileName());
            } catch (Exception e) {
                throw new RuntimeException("Could not read PDF from S3 for note " + note.getId(), e);
            }
        }
        try {
            Path file = Paths.get(STORAGE_DIR, note.getFileName());
            if (!Files.exists(file)) {
                throw new RuntimeException("PDF file is missing for note " + note.getId());
            }
            byte[] gzipped = Files.readAllBytes(file);
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            try (InputStream in = new GZIPInputStream(new ByteArrayInputStream(gzipped))) {
                in.transferTo(out);
            }
            return out.toByteArray();
        } catch (IOException e) {
            throw new RuntimeException("Could not read PDF file for note " + note.getId(), e);
        }
    }

    private void deleteFileFromDisk(String fileName) {
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

    private Map<String, Object> toMap(PdfNote note, HttpServletRequest request) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", note.getId());
        m.put("title", note.getTitle());
        m.put("content", note.getContent());
        m.put("createdByUserId", note.getCreatedByUserId());
        User author = note.getCreatedByUserId() == null ? null
                : userRepository.findById(note.getCreatedByUserId()).orElse(null);
        m.put("createdByName", author != null ? author.getName() : null);
        m.put("originalSize", note.getOriginalSize());
        m.put("storedSize", note.getStoredSize());
        m.put("fileUrl", buildAbsoluteUrl(request) + "/api/pdf-notes/" + note.getId() + "/file");
        m.put("createdAt", note.getCreatedAt());
        return m;
    }

    private String buildAbsoluteUrl(HttpServletRequest request) {
        String scheme = request.getScheme();
        String serverName = request.getServerName();
        int port = request.getServerPort();
        StringBuilder sb = new StringBuilder(scheme).append("://").append(serverName);
        if (!(("http".equals(scheme) && port == 80) || ("https".equals(scheme) && port == 443))) {
            sb.append(':').append(port);
        }
        String context = request.getContextPath();
        if (context != null && !context.isEmpty()) sb.append(context);
        return sb.toString();
    }

    private String safeFileName(String title) {
        String cleaned = title.replaceAll("[^a-zA-Z0-9 _\\-]", "").trim().replace(' ', '_');
        return cleaned.isEmpty() ? "notes" : cleaned;
    }
}
