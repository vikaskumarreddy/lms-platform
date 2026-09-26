package com.institute.lms.service;

import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.AwsCredentialsProvider;
import software.amazon.awssdk.auth.credentials.DefaultCredentialsProvider;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.core.ResponseBytes;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.S3ClientBuilder;
import software.amazon.awssdk.services.s3.model.*;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.GetObjectPresignRequest;

import java.io.IOException;
import java.net.URI;
import java.time.Duration;

/**
 * Service for managing media, documents, videos, and images on AWS S3.
 * Organized hierarchically by: academy/{academyId}/{videos|pdf|images}/{fileName}.
 */
@Service
public class S3StorageService {

    private static final Logger log = LoggerFactory.getLogger(S3StorageService.class);

    @Value("${aws.region:us-east-1}")
    private String region;

    @Value("${aws.s3.bucket:axisora-lms-media}")
    private String bucket;

    @Value("${aws.s3.access-key:}")
    private String accessKey;

    @Value("${aws.s3.secret-key:}")
    private String secretKey;

    @Value("${aws.s3.endpoint:}")
    private String endpoint;

    @Value("${aws.s3.enabled:true}")
    private boolean enabled;

    private S3Client s3Client;
    private S3Presigner presigner;

    @PostConstruct
    public void init() {
        if (!enabled) {
            log.info("AWS S3 Storage is disabled by configuration.");
            return;
        }

        try {
            AwsCredentialsProvider credentialsProvider;
            if (accessKey != null && !accessKey.trim().isEmpty() &&
                secretKey != null && !secretKey.trim().isEmpty()) {
                credentialsProvider = StaticCredentialsProvider.create(
                        AwsBasicCredentials.create(accessKey.trim(), secretKey.trim())
                );
            } else {
                credentialsProvider = DefaultCredentialsProvider.create();
            }

            S3ClientBuilder builder = S3Client.builder()
                    .region(Region.of(region))
                    .credentialsProvider(credentialsProvider);

            software.amazon.awssdk.services.s3.presigner.S3Presigner.Builder presignerBuilder =
                    S3Presigner.builder()
                            .region(Region.of(region))
                            .credentialsProvider(credentialsProvider);

            if (endpoint != null && !endpoint.trim().isEmpty()) {
                URI endpointUri = URI.create(endpoint.trim());
                builder.endpointOverride(endpointUri).forcePathStyle(true);
                presignerBuilder.endpointOverride(endpointUri);
            }

            this.s3Client = builder.build();
            this.presigner = presignerBuilder.build();
            log.info("AWS S3 Storage initialized for bucket '{}' in region '{}'.", bucket, region);
        } catch (Exception e) {
            log.error("Failed to initialize AWS S3 client: {}", e.getMessage(), e);
        }
    }

    @PreDestroy
    public void close() {
        if (s3Client != null) {
            try { s3Client.close(); } catch (Exception ignored) {}
        }
        if (presigner != null) {
            try { presigner.close(); } catch (Exception ignored) {}
        }
    }

    public boolean isConfigured() {
        return enabled && s3Client != null;
    }

    public String getBucket() {
        return bucket;
    }

    /**
     * Resolves the hierarchical key format: academy/{academyId}/{category}/{fileName}
     * Categories: "videos", "pdf", "images"
     */
    public String buildKey(Long academyId, String category, String fileName) {
        String acad = (academyId != null && academyId > 0) ? String.valueOf(academyId) : "1";
        String cat = normalizeCategory(category, fileName);
        return "academy/" + acad + "/" + cat + "/" + fileName;
    }

    public String normalizeCategory(String category, String fileName) {
        String cat = (category != null) ? category.trim().toLowerCase() : "";
        String fName = (fileName != null) ? fileName.trim().toLowerCase() : "";

        if (cat.contains("video") || fName.endsWith(".mp4") || fName.endsWith(".webm") || fName.endsWith(".mkv") || fName.endsWith(".mov")) {
            return "videos";
        }
        if (cat.contains("pdf") || fName.endsWith(".pdf") || cat.contains("document") || cat.contains("doc")) {
            return "pdf";
        }
        if (cat.contains("image") || cat.contains("logo") || cat.contains("thumbnail") || cat.contains("photo")
                || fName.endsWith(".png") || fName.endsWith(".jpg") || fName.endsWith(".jpeg") || fName.endsWith(".webp") || fName.endsWith(".svg")) {
            return "images";
        }
        return "pdf"; // Default fallback
    }

    /**
     * Uploads bytes to S3 under the specified key.
     */
    public String upload(String key, byte[] bytes, String contentType) {
        if (!isConfigured()) {
            throw new IllegalStateException("AWS S3 client is not configured or enabled.");
        }
        PutObjectRequest putRequest = PutObjectRequest.builder()
                .bucket(bucket)
                .key(key)
                .contentType(contentType != null && !contentType.isBlank()
                        ? contentType
                        : "application/octet-stream")
                .build();

        s3Client.putObject(putRequest, RequestBody.fromBytes(bytes));
        log.info("Successfully uploaded object to S3: s3://{}/{}", bucket, key);
        return key;
    }

    /**
     * Downloads an object from S3 as byte array.
     */
    public byte[] download(String key) throws IOException {
        if (!isConfigured()) {
            throw new IllegalStateException("AWS S3 client is not configured or enabled.");
        }
        try {
            GetObjectRequest getRequest = GetObjectRequest.builder()
                    .bucket(bucket)
                    .key(key)
                    .build();
            ResponseBytes<GetObjectResponse> responseBytes = s3Client.getObjectAsBytes(getRequest);
            return responseBytes.asByteArray();
        } catch (NoSuchKeyException e) {
            log.warn("S3 object not found for key: {}", key);
            throw e;
        }
    }

    /**
     * Generates a presigned GET URL for streaming or downloading with range request support.
     */
    public String generatePresignedUrl(String key, Duration duration) {
        if (presigner == null) {
            return null;
        }
        try {
            GetObjectRequest getObjectRequest = GetObjectRequest.builder()
                    .bucket(bucket)
                    .key(key)
                    .build();

            GetObjectPresignRequest presignRequest = GetObjectPresignRequest.builder()
                    .signatureDuration(duration != null ? duration : Duration.ofHours(1))
                    .getObjectRequest(getObjectRequest)
                    .build();

            return presigner.presignGetObject(presignRequest).url().toString();
        } catch (Exception e) {
            log.warn("Failed to generate presigned URL for key '{}': {}", key, e.getMessage());
            return null;
        }
    }

    /**
     * Deletes an object from S3.
     */
    public void delete(String key) {
        if (!isConfigured() || key == null || key.isBlank()) return;
        try {
            DeleteObjectRequest deleteRequest = DeleteObjectRequest.builder()
                    .bucket(bucket)
                    .key(key)
                    .build();
            s3Client.deleteObject(deleteRequest);
            log.info("Deleted object from S3: s3://{}/{}", bucket, key);
        } catch (Exception e) {
            log.warn("Error deleting S3 object '{}': {}", key, e.getMessage());
        }
    }

    /**
     * Checks if an object exists in S3.
     */
    public boolean exists(String key) {
        if (!isConfigured() || key == null || key.isBlank()) return false;
        try {
            HeadObjectRequest headRequest = HeadObjectRequest.builder()
                    .bucket(bucket)
                    .key(key)
                    .build();
            s3Client.headObject(headRequest);
            return true;
        } catch (NoSuchKeyException e) {
            return false;
        } catch (Exception e) {
            return false;
        }
    }
}
