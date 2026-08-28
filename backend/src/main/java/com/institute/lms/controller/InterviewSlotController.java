package com.institute.lms.controller;

import com.institute.lms.dto.placement.InterviewSlotHistoryDTO;
import com.institute.lms.entity.InterviewSlot;
import com.institute.lms.entity.PlacementDrive;
import com.institute.lms.entity.User;
import com.institute.lms.repository.InterviewSlotRepository;
import com.institute.lms.repository.PlacementDriveRepository;
import com.institute.lms.repository.UserRepository;
import com.institute.lms.service.FcmService;
import com.institute.lms.util.UserContext;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.Comparator;
import java.util.List;
import java.util.Map;

/**
 * Manages interview slots for INTERNAL placement drives: admin creates the
 * available slots, students book ("Schedule my slot") one of them, closing
 * the loop between a placement drive and actual interview tracking.
 */
@RestController
@RequestMapping("/api/interview-slots")
public class InterviewSlotController {

    private final InterviewSlotRepository interviewSlotRepository;
    private final PlacementDriveRepository placementDriveRepository;
    private final UserRepository userRepository;
    private final FcmService fcmService;
    private final UserContext userContext;

    public InterviewSlotController(InterviewSlotRepository interviewSlotRepository,
                                    PlacementDriveRepository placementDriveRepository,
                                    UserRepository userRepository, FcmService fcmService,
                                    UserContext userContext) {
        this.interviewSlotRepository = interviewSlotRepository;
        this.placementDriveRepository = placementDriveRepository;
        this.userRepository = userRepository;
        this.fcmService = fcmService;
        this.userContext = userContext;
    }

    /** All slots for a drive (used by both admin management and the student booking screen). */
    @GetMapping("/drive/{driveId}")
    public List<InterviewSlot> getSlotsForDrive(@PathVariable Long driveId) {
        return interviewSlotRepository.findByDriveIdOrderBySlotTimeAsc(driveId);
    }

    /** The student's own booked slots, across all drives, most recent first. */
    @GetMapping("/student/{studentId}")
    public List<InterviewSlotHistoryDTO> getSlotsForStudent(@PathVariable Long studentId) {
        return interviewSlotRepository.findByBookedByUserId(studentId).stream()
                .sorted(Comparator.comparing(InterviewSlot::getSlotTime).reversed())
                .map(slot -> {
                    InterviewSlotHistoryDTO dto = new InterviewSlotHistoryDTO();
                    dto.setId(slot.getId());
                    dto.setDriveId(slot.getDriveId());
                    dto.setLocation(slot.getLocation());
                    dto.setSlotTime(slot.getSlotTime());
                    dto.setStatus(slot.getStatus());
                    PlacementDrive drive = slot.getDriveId() != null
                            ? placementDriveRepository.findById(slot.getDriveId()).orElse(null)
                            : null;
                    if (drive != null) {
                        dto.setCompanyName(drive.getCompanyName());
                        dto.setRole(drive.getRole());
                    }
                    return dto;
                })
                .toList();
    }

    /** Admin creates a new open slot for an internal drive. */
    @PostMapping
    public ResponseEntity<InterviewSlot> createSlot(@RequestBody Map<String, Object> body) {
        userContext.requireOrgAdmin();
        Long driveId = body.get("driveId") != null ? ((Number) body.get("driveId")).longValue() : null;
        PlacementDrive drive = driveId != null ? placementDriveRepository.findById(driveId).orElse(null) : null;
        if (drive == null) return ResponseEntity.badRequest().build();

        InterviewSlot slot = new InterviewSlot();
        slot.setDriveId(driveId);
        slot.setSlotTime(LocalDateTime.parse(String.valueOf(body.get("slotTime"))));
        slot.setLocation(body.get("location") != null ? String.valueOf(body.get("location")) : null);
        slot.setNotes(body.get("notes") != null ? String.valueOf(body.get("notes")) : null);
        slot.setStatus("AVAILABLE");
        return ResponseEntity.ok(interviewSlotRepository.save(slot));
    }

    /** Student books an available slot ("Schedule my slot"). */
    @PostMapping("/{id}/book")
    public ResponseEntity<InterviewSlot> bookSlot(@PathVariable Long id, @RequestBody Map<String, Object> body) {
        Long userId = body.get("userId") != null ? ((Number) body.get("userId")).longValue() : null;
        User user = userId != null ? userRepository.findById(userId).orElse(null) : null;
        if (user == null) return ResponseEntity.badRequest().build();

        return interviewSlotRepository.findById(id)
                .map(slot -> {
                    if (!"AVAILABLE".equals(slot.getStatus())) {
                        return ResponseEntity.status(409).<InterviewSlot>build();
                    }
                    // One slot per student per drive until an admin frees it back up.
                    boolean alreadyHasSlotOnThisDrive = !interviewSlotRepository
                            .findByDriveIdAndBookedByUserId(slot.getDriveId(), userId).isEmpty();
                    if (alreadyHasSlotOnThisDrive) {
                        return ResponseEntity.status(409).<InterviewSlot>build();
                    }
                    slot.setBookedByUserId(userId);
                    slot.setBookedAt(LocalDateTime.now());
                    slot.setStatus("BOOKED");
                    InterviewSlot saved = interviewSlotRepository.save(slot);

                    if (user.getFcmToken() != null && !user.getFcmToken().isBlank()) {
                        fcmService.sendToToken(user.getFcmToken(), "Interview Slot Confirmed",
                                "Your interview slot on " + slot.getSlotTime() + " is confirmed.", Map.of());
                    }
                    return ResponseEntity.ok(saved);
                })
                .orElse(ResponseEntity.notFound().build());
    }

    /** Student cancels their own booking, freeing the slot back up. */
    @PostMapping("/{id}/cancel")
    public ResponseEntity<InterviewSlot> cancelBooking(@PathVariable Long id) {
        return interviewSlotRepository.findById(id)
                .map(slot -> {
                    slot.setBookedByUserId(null);
                    slot.setBookedAt(null);
                    slot.setStatus("AVAILABLE");
                    return ResponseEntity.ok(interviewSlotRepository.save(slot));
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @PutMapping("/{id}/status")
    public ResponseEntity<InterviewSlot> updateStatus(@PathVariable Long id, @RequestBody Map<String, String> body) {
        userContext.requireOrgAdmin();
        return interviewSlotRepository.findById(id)
                .map(slot -> {
                    slot.setStatus(body.getOrDefault("status", slot.getStatus()));
                    return ResponseEntity.ok(interviewSlotRepository.save(slot));
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteSlot(@PathVariable Long id) {
        userContext.requireOrgAdmin();
        if (!interviewSlotRepository.existsById(id)) return ResponseEntity.notFound().build();
        interviewSlotRepository.deleteById(id);
        return ResponseEntity.ok().build();
    }
}
