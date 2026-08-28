package com.institute.lms.controller;

import com.institute.lms.entity.AssessmentType;
import com.institute.lms.entity.CompanyKitFavorite;
import com.institute.lms.entity.CompanyQuestionKit;
import com.institute.lms.repository.CompanyKitFavoriteRepository;
import com.institute.lms.repository.CompanyQuestionKitRepository;
import com.institute.lms.service.AssessmentPaperService;
import com.institute.lms.util.UserContext;
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
 * {@link AssessmentPaperController} unchanged) or a pasted PDF URL viewed in the
 * mobile in-app browser. This controller only owns the tile metadata + favorites,
 * exactly mirroring how AssignmentController/ExamController own metadata while
 * AssessmentPaperController separately owns question papers.
 */
@RestController
@RequestMapping("/api/company-kits")
public class CompanyQuestionKitController {

    private final CompanyQuestionKitRepository kitRepository;
    private final CompanyKitFavoriteRepository favoriteRepository;
    private final AssessmentPaperService paperService;
    private final UserContext userContext;

    public CompanyQuestionKitController(CompanyQuestionKitRepository kitRepository,
                                        CompanyKitFavoriteRepository favoriteRepository,
                                        AssessmentPaperService paperService,
                                        UserContext userContext) {
        this.kitRepository = kitRepository;
        this.favoriteRepository = favoriteRepository;
        this.paperService = paperService;
        this.userContext = userContext;
    }

    // ------------------------------------------------------------------ listing

    /** Admin tile list - includes unpublished kits. */
    @GetMapping
    public List<Map<String, Object>> list() {
        userContext.requireOrgAdminOrFaculty();
        return kitRepository.findAllByOrderByCompanyNameAsc().stream()
                .map(this::toMap).collect(Collectors.toList());
    }

    /** Student tile list - published only. Optional favoriteStudentId flags each tile. */
    @GetMapping("/published")
    public List<Map<String, Object>> published(@RequestParam(required = false) Long studentId) {
        Set<Long> favorites = studentId == null ? Set.of() : favoriteRepository.findByStudentId(studentId).stream()
                .map(CompanyKitFavorite::getKitId).collect(Collectors.toSet());
        return kitRepository.findByIsPublishedTrueOrderByCompanyNameAsc().stream()
                .map(kit -> {
                    Map<String, Object> m = toMap(kit);
                    m.put("isFavorite", favorites.contains(kit.getId()));
                    return m;
                }).collect(Collectors.toList());
    }

    @GetMapping("/{id}")
    public ResponseEntity<Map<String, Object>> get(@PathVariable Long id) {
        return kitRepository.findById(id)
                .map(kit -> ResponseEntity.ok(toMap(kit)))
                .orElseGet(() -> ResponseEntity.notFound().build());
    }

    // ------------------------------------------------------------------- admin CRUD

    @PostMapping
    @Transactional
    public ResponseEntity<?> create(@RequestBody Map<String, Object> body) {
        userContext.requireOrgAdminOrFaculty();
        String companyName = str(body.get("companyName"));
        if (companyName == null || companyName.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("error", "companyName is required."));
        }
        CompanyQuestionKit kit = new CompanyQuestionKit();
        apply(kit, body);
        return ResponseEntity.ok(toMap(kitRepository.save(kit)));
    }

    @PutMapping("/{id}")
    @Transactional
    public ResponseEntity<?> update(@PathVariable Long id, @RequestBody Map<String, Object> body) {
        userContext.requireOrgAdminOrFaculty();
        CompanyQuestionKit kit = kitRepository.findById(id).orElse(null);
        if (kit == null) return ResponseEntity.notFound().build();
        apply(kit, body);
        return ResponseEntity.ok(toMap(kitRepository.save(kit)));
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
        if (body.containsKey("description")) kit.setDescription(str(body.get("description")));
        if (body.containsKey("isPublished")) {
            Object v = body.get("isPublished");
            kit.setIsPublished(v instanceof Boolean b ? b : Boolean.parseBoolean(String.valueOf(v)));
        }
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

    private Map<String, Object> toMap(CompanyQuestionKit kit) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", kit.getId());
        m.put("companyName", kit.getCompanyName());
        m.put("logoUrl", kit.getLogoUrl());
        m.put("tags", kit.getTags());
        m.put("mode", kit.getMode().name());
        m.put("pdfUrl", kit.getPdfUrl());
        m.put("description", kit.getDescription());
        m.put("isPublished", kit.getIsPublished());
        m.put("createdAt", kit.getCreatedAt());
        return m;
    }

    private static String str(Object value) {
        return value == null ? null : String.valueOf(value);
    }

    private static Long num(Object value) {
        return value instanceof Number n ? n.longValue() : null;
    }
}
