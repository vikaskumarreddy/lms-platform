package com.institute.lms.service;

import com.institute.lms.entity.MediaItem;
import com.institute.lms.entity.Organization;
import com.institute.lms.entity.PdfDocument;
import com.institute.lms.entity.PdfNote;
import com.institute.lms.repository.MediaItemRepository;
import com.institute.lms.repository.OrganizationRepository;
import com.institute.lms.repository.PdfDocumentRepository;
import com.institute.lms.repository.PdfNoteRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.List;
import java.util.zip.GZIPInputStream;

/**
 * Migrates existing on-disk storage (uploads/media, uploads/pdf-notes,
 * uploads/pdf-documents, uploads/organization-logos) to AWS S3 under
 * the hierarchy: academy/{academyId}/{videos|pdf|images}/{fileName}.
 */
@Service
public class MediaStorageMigrationService {

    private static final Logger log = LoggerFactory.getLogger(MediaStorageMigrationService.class);

    private final S3StorageService s3StorageService;
    private final MediaItemRepository mediaItemRepository;
    private final PdfNoteRepository pdfNoteRepository;
    private final PdfDocumentRepository pdfDocumentRepository;
    private final OrganizationRepository organizationRepository;

    public MediaStorageMigrationService(S3StorageService s3StorageService,
                                        MediaItemRepository mediaItemRepository,
                                        PdfNoteRepository pdfNoteRepository,
                                        PdfDocumentRepository pdfDocumentRepository,
                                        OrganizationRepository organizationRepository) {
        this.s3StorageService = s3StorageService;
        this.mediaItemRepository = mediaItemRepository;
        this.pdfNoteRepository = pdfNoteRepository;
        this.pdfDocumentRepository = pdfDocumentRepository;
        this.organizationRepository = organizationRepository;
    }

    @EventListener(ApplicationReadyEvent.class)
    public void onStartup() {
        if (!s3StorageService.isConfigured()) {
            log.info("S3 is not configured; skipping media migration to S3.");
            return;
        }
        // Run migration in background/ready event without blocking application startup
        new Thread(this::migrateAllToS3, "media-s3-migration-thread").start();
    }

    @Transactional
    public void migrateAllToS3() {
        if (!s3StorageService.isConfigured()) {
            log.warn("Cannot run S3 migration: S3 is not enabled or configured.");
            return;
        }
        log.info("Starting media and documents migration to AWS S3...");

        migrateMediaItems();
        migratePdfNotes();
        migratePdfDocuments();
        migrateOrganizationLogos();

        log.info("Finished media and documents migration to AWS S3.");
    }

    private void migrateMediaItems() {
        try {
            List<MediaItem> items = mediaItemRepository.findAll();
            for (MediaItem item : items) {
                String fileName = item.getFileName();
                if (fileName == null || fileName.startsWith("academy/")) {
                    continue; // Already on S3 or missing
                }

                Path localPath = Paths.get("uploads/media", fileName);
                if (!Files.exists(localPath)) {
                    continue;
                }

                try {
                    byte[] rawBytes = readDecompressedBytes(localPath);
                    Long academyId = item.getOrganizationId() != null ? item.getOrganizationId() : 1L;
                    String ext = fileName.endsWith(".bin.gz") ? "" : fileName.substring(fileName.lastIndexOf('.'));
                    if (ext.isEmpty()) {
                        ext = "video".equalsIgnoreCase(item.getMediaType()) ? ".mp4" : ".pdf";
                    }
                    String newName = fileName.replace(".bin.gz", ext);
                    String category = s3StorageService.normalizeCategory(item.getMediaType(), newName);
                    String s3Key = s3StorageService.buildKey(academyId, category, newName);

                    s3StorageService.upload(s3Key, rawBytes, item.getMimeType());
                    item.setFileName(s3Key);
                    item.setStoredSize((long) rawBytes.length);
                    mediaItemRepository.save(item);
                    log.info("Migrated MediaItem id={} to S3: {}", item.getId(), s3Key);
                } catch (Exception e) {
                    log.error("Failed to migrate MediaItem id={}: {}", item.getId(), e.getMessage());
                }
            }
        } catch (Exception e) {
            log.error("Error migrating media items to S3: {}", e.getMessage());
        }
    }

    private void migratePdfNotes() {
        try {
            List<PdfNote> notes = pdfNoteRepository.findAll();
            for (PdfNote note : notes) {
                String fileName = note.getFileName();
                if (fileName == null || fileName.startsWith("academy/")) {
                    continue;
                }

                Path localPath = Paths.get("uploads/pdf-notes", fileName);
                if (!Files.exists(localPath)) {
                    continue;
                }

                try {
                    byte[] rawBytes = readDecompressedBytes(localPath);
                    Long academyId = note.getOrganizationId() != null ? note.getOrganizationId() : 1L;
                    String newName = fileName.replace(".pdf.gz", ".pdf");
                    String s3Key = s3StorageService.buildKey(academyId, "pdf", newName);

                    s3StorageService.upload(s3Key, rawBytes, "application/pdf");
                    note.setFileName(s3Key);
                    note.setStoredSize((long) rawBytes.length);
                    pdfNoteRepository.save(note);
                    log.info("Migrated PdfNote id={} to S3: {}", note.getId(), s3Key);
                } catch (Exception e) {
                    log.error("Failed to migrate PdfNote id={}: {}", note.getId(), e.getMessage());
                }
            }
        } catch (Exception e) {
            log.error("Error migrating PDF notes to S3: {}", e.getMessage());
        }
    }

    private void migratePdfDocuments() {
        try {
            List<PdfDocument> docs = pdfDocumentRepository.findAll();
            for (PdfDocument doc : docs) {
                String fileName = doc.getFileName();
                if (fileName == null || fileName.startsWith("academy/")) {
                    continue;
                }

                Path localPath = Paths.get("uploads/pdf-documents", fileName);
                if (!Files.exists(localPath)) {
                    continue;
                }

                try {
                    byte[] rawBytes = readDecompressedBytes(localPath);
                    Long academyId = doc.getOrganizationId() != null ? doc.getOrganizationId() : 1L;
                    String newName = fileName.replace(".pdf.gz", ".pdf");
                    String s3Key = s3StorageService.buildKey(academyId, "pdf", newName);

                    s3StorageService.upload(s3Key, rawBytes, "application/pdf");
                    doc.setFileName(s3Key);
                    doc.setStoredSize((long) rawBytes.length);
                    pdfDocumentRepository.save(doc);
                    log.info("Migrated PdfDocument id={} to S3: {}", doc.getId(), s3Key);
                } catch (Exception e) {
                    log.error("Failed to migrate PdfDocument id={}: {}", doc.getId(), e.getMessage());
                }
            }
        } catch (Exception e) {
            log.error("Error migrating PDF documents to S3: {}", e.getMessage());
        }
    }

    private void migrateOrganizationLogos() {
        try {
            List<Organization> orgs = organizationRepository.findAll();
            for (Organization org : orgs) {
                String logoUrl = org.getLogoUrl();
                if (logoUrl == null || !logoUrl.contains("/uploads/organization-logos/")) {
                    continue;
                }

                String fileName = logoUrl.substring(logoUrl.lastIndexOf('/') + 1);
                Path localPath = Paths.get("uploads/organization-logos", fileName);
                if (!Files.exists(localPath)) {
                    continue;
                }

                try {
                    byte[] rawBytes = Files.readAllBytes(localPath);
                    Long academyId = org.getId();
                    String s3Key = s3StorageService.buildKey(academyId, "images", fileName);

                    s3StorageService.upload(s3Key, rawBytes, "image/png");
                    org.setLogoUrl("/api/media/serve-key?key=" + s3Key);
                    organizationRepository.save(org);
                    log.info("Migrated Organization id={} logo to S3: {}", org.getId(), s3Key);
                } catch (Exception e) {
                    log.error("Failed to migrate Organization id={} logo: {}", org.getId(), e.getMessage());
                }
            }
        } catch (Exception e) {
            log.error("Error migrating organization logos to S3: {}", e.getMessage());
        }
    }

    private byte[] readDecompressedBytes(Path file) throws Exception {
        byte[] fileBytes = Files.readAllBytes(file);
        try (InputStream in = new GZIPInputStream(new ByteArrayInputStream(fileBytes));
             ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            in.transferTo(out);
            return out.toByteArray();
        } catch (Exception notGzip) {
            return fileBytes; // Return uncompressed if it wasn't gzipped
        }
    }
}
