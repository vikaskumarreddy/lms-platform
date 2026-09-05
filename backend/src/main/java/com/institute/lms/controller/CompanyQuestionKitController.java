package com.institute.lms.controller;

import com.institute.lms.entity.AssessmentType;
import com.institute.lms.entity.CompanyKitFavorite;
import com.institute.lms.entity.CompanyQuestionKit;
import com.institute.lms.entity.MediaItem;
import com.institute.lms.repository.CompanyKitFavoriteRepository;
import com.institute.lms.repository.CompanyQuestionKitRepository;
import com.institute.lms.repository.MediaItemRepository;
import com.institute.lms.service.AssessmentPaperService;
import com.institute.lms.util.UserContext;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * "Company Questions" tiles - each is either a full in-app question paper
 * (questions owned separately via {@code AssessmentType.COMPANY_KIT}, reusing
 * {@link AssessmentPaperController} unchanged) or a PDF viewed in the mobile
 * in-app browser. A PDF can be an external URL or a self-hosted PdfNote picked
 * from the faculty "Create PDF" library. This controller only owns the tile
 * metadata + favorites, exactly mirroring how AssignmentController/ExamController
 * own metadata while AssessmentPaperController separately owns question papers.
 */
@RestController
@RequestMapping("/api/company-kits")
public class CompanyQuestionKitController {

    private final CompanyQuestionKitRepository kitRepository;
    private final CompanyKitFavoriteRepository favoriteRepository;
    private final AssessmentPaperService paperService;
    private final MediaItemRepository mediaItemRepository;
    private final UserContext userContext;

    public CompanyQuestionKitController(CompanyQuestionKitRepository kitRepository,
                                        CompanyKitFavoriteRepository favoriteRepository,
                                        AssessmentPaperService paperService,
                                        MediaItemRepository mediaItemRepository,
                                        UserContext userContext) {
        this.kitRepository = kitRepository;
        this.favoriteRepository = favoriteRepository;
        this.paperService = paperService;
        this.mediaItemRepository = mediaItemRepository;
        this.userContext = userContext;
    }

    // ------------------------------------------------------------------ listing

    /** Admin tile list - includes unpublished kits. */
    @GetMapping
    public List<Map<String, Object>> list(HttpServletRequest request) {
        userContext.requireOrgAdminOrFaculty();
        return kitRepository.findAllByOrderByCompanyNameAsc().stream()
                .map(kit -> toMap(kit, request)).collect(Collectors.toList());
    }

    /** Student tile list - published only. Optional favoriteStudentId flags each tile. */
    @GetMapping("/published")
    public List<Map<String, Object>> published(@RequestParam(required = false) Long studentId,
                                               HttpServletRequest request) {
        Set<Long> favorites = studentId == null ? Set.of() : favoriteRepository.findByStudentId(studentId).stream()
                .map(CompanyKitFavorite::getKitId).collect(Collectors.toSet());
        return kitRepository.findByIsPublishedTrueOrderByCompanyNameAsc().stream()
                .map(kit -> {
                    Map<String, Object> m = toMap(kit, request);
                    m.put("isFavorite", favorites.contains(kit.getId()));
                    return m;
                }).collect(Collectors.toList());
    }

    @GetMapping("/{id}")
    public ResponseEntity<Map<String, Object>> get(@PathVariable Long id, HttpServletRequest request) {
        return kitRepository.findById(id)
                .map(kit -> ResponseEntity.ok(toMap(kit, request)))
                .orElseGet(() -> ResponseEntity.notFound().build());
    }

    // ------------------------------------------------------------------- admin CRUD

    @PostMapping
    @Transactional
    public ResponseEntity<?> create(@RequestBody Map<String, Object> body, HttpServletRequest request) {
        userContext.requireOrgAdminOrFaculty();
        String companyName = str(body.get("companyName"));
        if (companyName == null || companyName.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("error", "companyName is required."));
        }
        CompanyQuestionKit kit = new CompanyQuestionKit();
        apply(kit, body);
        resolveSelfHostedPdf(kit, request);
        return ResponseEntity.ok(toMap(kitRepository.save(kit), request));
    }

    @PutMapping("/{id}")
    @Transactional
    public ResponseEntity<?> update(@PathVariable Long id, @RequestBody Map<String, Object> body,
                                    HttpServletRequest request) {
        userContext.requireOrgAdminOrFaculty();
        CompanyQuestionKit kit = kitRepository.findById(id).orElse(null);
        if (kit == null) return ResponseEntity.notFound().build();
        apply(kit, body);
        resolveSelfHostedPdf(kit, request);
        return ResponseEntity.ok(toMap(kitRepository.save(kit), request));
    }

    @DeleteMapping("/{id}")
    @Transactional
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        userContext.requireOrgAdminOrFaculty();
        paperService.deletePaper(AssessmentType.COMPANY_KIT, id);
        favoriteRepository.deleteByKitId(id);
        kitRepository.deleteById(id);
        return ResponseEntity.ok().build();
    }

    private void apply(CompanyQuestionKit kit, Map<String, Object> body) {
        if (body.containsKey("companyName")) kit.setCompanyName(str(body.get("companyName")));
        if (body.containsKey("logoUrl")) kit.setLogoUrl(str(body.get("logoUrl")));
        if (body.containsKey("tags")) kit.setTags(str(body.get("tags")));
        if (body.containsKey("mode")) {
            String mode = str(body.get("mode"));
            kit.setMode(mode != null && mode.equalsIgnoreCase("PDF")
                    ? CompanyQuestionKit.Mode.PDF : CompanyQuestionKit.Mode.CONTENT);
        }
        if (body.containsKey("pdfUrl")) kit.setPdfUrl(str(body.get("pdfUrl")));
        if (body.containsKey("pdfSource")) {
            String source = str(body.get("pdfSource"));
            kit.setPdfSource("SELF".equalsIgnoreCase(source) ? "SELF" : "URL");
        }
        if (body.get("pdfNoteId") instanceof Number n) {
            kit.setPdfNoteId(n.longValue());
        } else if (body.containsKey("pdfNoteId")) {
            kit.setPdfNoteId(null);
        }
        if (body.containsKey("description")) kit.setDescription(str(body.get("description")));
        if (body.containsKey("isPublished")) {
            Object v = body.get("isPublished");
            kit.setIsPublished(v instanceof Boolean b ? b : Boolean.parseBoolean(String.valueOf(v)));
        }
    }

    /**
     * When the tile uses a self-hosted uploaded PDF (Media &amp; Files), resolve
     * the persisted pdfUrl to the item's absolute serve URL so the mobile app
     * can fetch it without any extra lookup. External-URL tiles keep the pasted
     * URL untouched. pdfNoteId now stores a media_items.id (the old "Create PDF"
     * generator was replaced by direct file uploads — see MediaController).
     */
    private void resolveSelfHostedPdf(CompanyQuestionKit kit, HttpServletRequest request) {
        if (!"SELF".equals(kit.getPdfSource()) || kit.getPdfNoteId() == null) return;
        mediaItemRepository.findById(kit.getPdfNoteId()).ifPresent(item -> {
            String origin = buildAbsoluteUrl(request);
            kit.setPdfUrl(origin + "/api/media/" + item.getId() + "/serve");
        });
    }

    // -------------------------------------------------------------------- favorites

    @GetMapping("/favorites/{studentId}")
    public List<Long> favorites(@PathVariable Long studentId) {
        return favoriteRepository.findByStudentId(studentId).stream()
                .map(CompanyKitFavorite::getKitId).collect(Collectors.toList());
    }

    /** Body: {studentId, kitId}. Toggles - adds if absent, removes if present. */
    @PostMapping("/favorites/toggle")
    @Transactional
    public ResponseEntity<?> toggleFavorite(@RequestBody Map<String, Object> body) {
        Long studentId = num(body.get("studentId"));
        Long kitId = num(body.get("kitId"));
        if (studentId == null || kitId == null) {
            return ResponseEntity.badRequest().body(Map.of("error", "studentId and kitId are required."));
        }
        var existing = favoriteRepository.findByStudentIdAndKitId(studentId, kitId);
        if (existing.isPresent()) {
            favoriteRepository.deleteByStudentIdAndKitId(studentId, kitId);
            return ResponseEntity.ok(Map.of("isFavorite", false));
        }
        CompanyKitFavorite favorite = new CompanyKitFavorite();
        favorite.setStudentId(studentId);
        favorite.setKitId(kitId);
        favoriteRepository.save(favorite);
        return ResponseEntity.ok(Map.of("isFavorite", true));
    }

    // ------------------------------------------------------------------------ helpers

    private Map<String, Object> toMap(CompanyQuestionKit kit, HttpServletRequest request) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", kit.getId());
        m.put("companyName", kit.getCompanyName());
        m.put("logoUrl", kit.getLogoUrl());
        m.put("tags", kit.getTags());
        m.put("mode", kit.getMode().name());
        m.put("pdfUrl", kit.getPdfUrl());
        m.put("pdfSource", kit.getPdfSource());
        m.put("pdfNoteId", kit.getPdfNoteId());
        m.put("description", kit.getDescription());
        m.put("isPublished", kit.getIsPublished());
        m.put("createdAt", kit.getCreatedAt());
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

    private static String str(Object value) {
        return value == null ? null : String.valueOf(value);
    }

    private static Long num(Object value) {
        return value instanceof Number n ? n.longValue() : null;
    }
}
