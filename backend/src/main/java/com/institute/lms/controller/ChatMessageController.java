package com.institute.lms.controller;

import com.institute.lms.entity.ChatMessage;
import com.institute.lms.entity.User;
import com.institute.lms.exception.BadRequestException;
import com.institute.lms.repository.ChatMessageRepository;
import com.institute.lms.service.FirebaseRealtimeSyncService;
import com.institute.lms.util.OrganizationContext;
import com.institute.lms.util.UserContext;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/chat")
public class ChatMessageController {

    private final ChatMessageRepository chatMessageRepository;
    private final UserContext userContext;
    private final OrganizationContext organizationContext;
    private final FirebaseRealtimeSyncService firebaseSyncService;
    private final com.institute.lms.service.NotificationService notificationService;

    public ChatMessageController(ChatMessageRepository chatMessageRepository,
                                 UserContext userContext,
                                 OrganizationContext organizationContext,
                                 FirebaseRealtimeSyncService firebaseSyncService,
                                 com.institute.lms.service.NotificationService notificationService) {
        this.chatMessageRepository = chatMessageRepository;
        this.userContext = userContext;
        this.organizationContext = organizationContext;
        this.firebaseSyncService = firebaseSyncService;
        this.notificationService = notificationService;
    }

    @GetMapping("/batch/{batchId}")
    public ResponseEntity<List<ChatMessage>> getBatchMessages(@PathVariable Long batchId) {
        return ResponseEntity.ok(chatMessageRepository.findByBatchIdOrderByCreatedAtAsc(batchId));
    }

    @PostMapping("/send")
    public ResponseEntity<ChatMessage> sendMessageDirect(@RequestBody Map<String, Object> body) {
        Object batchIdObj = body.get("batchId");
        if (batchIdObj == null) {
            throw BadRequestException.field("batchId", "batchId is required");
        }
        Long batchId;
        if (batchIdObj instanceof Number) {
            batchId = ((Number) batchIdObj).longValue();
        } else {
            batchId = Long.parseLong(batchIdObj.toString());
        }
        return sendMessage(batchId, body);
    }

    @PostMapping("/batch/{batchId}")
    public ResponseEntity<ChatMessage> sendMessage(@PathVariable Long batchId, @RequestBody Map<String, Object> body) {
        User sender = userContext.currentUser();
        if (sender == null) {
            return ResponseEntity.status(401).build();
        }

        String content = (String) body.get("content");
        if (content == null || content.trim().isEmpty()) {
            throw BadRequestException.field("content", "Message content is required");
        }

        String type = (String) body.getOrDefault("messageType", "TEXT");
        String codeLanguage = (String) body.get("codeLanguage");

        // Only faculty or admins can post announcements
        if ("ANNOUNCEMENT".equalsIgnoreCase(type) && !userContext.isAnyAdmin() && !userContext.isFaculty()) {
            type = "TEXT";
        }

        ChatMessage message = new ChatMessage();
        message.setBatchId(batchId);
        message.setSenderId(sender.getId());
        message.setSenderName(sender.getName());
        message.setSenderRole(sender.getRole() != null ? sender.getRole().name() : "STUDENT");
        message.setContent(content.trim());
        message.setMessageType(type.toUpperCase());
        message.setCodeLanguage(codeLanguage);
        message.setCreatedAt(LocalDateTime.now());

        ChatMessage saved = chatMessageRepository.save(message);

        // Sync with Firebase in real time if configured
        firebaseSyncService.syncMessage(organizationContext.getCurrentOrgId(), saved);

        // Notify batch students (excluding sender)
        String preview = content.trim().length() > 100 ? content.trim().substring(0, 97) + "..." : content.trim();
        String studentNotifTitle = "ANNOUNCEMENT".equalsIgnoreCase(type)
                ? "📢 Batch Announcement from " + sender.getName()
                : "💬 " + sender.getName() + " in Batch Community";
        List<User> studentAudience = notificationService.audienceForBatches(List.of(batchId))
                .stream()
                .filter(u -> !u.getId().equals(sender.getId()))
                .toList();
        notificationService.safeNotify(studentAudience, studentNotifTitle, preview, "chat", "/chat", "BATCH", batchId);

        // If a student sent the message, notify faculty & admins
        if (sender.getRole() == User.UserRole.STUDENT) {
            notificationService.notifyFacultyAndAdmins(
                    "💬 " + sender.getName() + " (Batch #" + batchId + ")",
                    preview,
                    "chat",
                    "/batches",
                    batchId
            );
        }

        return ResponseEntity.ok(saved);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteMessage(@PathVariable Long id) {
        userContext.requireOrgAdminOrFaculty();
        chatMessageRepository.deleteById(id);
        return ResponseEntity.ok().build();
    }
}
