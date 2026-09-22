package com.institute.lms.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "chat_messages")
@Data
@NoArgsConstructor
@EqualsAndHashCode(callSuper = true)
public class ChatMessage extends BaseEntity {

    @Column(name = "batch_id")
    private Long batchId;

    @Column(name = "sender_id", nullable = false)
    private Long senderId;

    @Column(name = "sender_name", nullable = false)
    private String senderName;

    @Column(name = "sender_role", nullable = false)
    private String senderRole;

    @Column(columnDefinition = "TEXT", nullable = false)
    private String content;

    @Column(name = "message_type", nullable = false)
    private String messageType = "TEXT"; // TEXT, CODE, ANNOUNCEMENT

    @Column(name = "code_language")
    private String codeLanguage;
}
