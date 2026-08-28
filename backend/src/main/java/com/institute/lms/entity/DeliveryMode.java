package com.institute.lms.entity;

/**
 * How an assignment or exam reaches the student.
 *
 * <p>{@link #WEB} keeps the original behaviour — the institute publishes a
 * {@code link} and the mobile app opens it in the embedded browser.
 * {@link #IN_APP} means a question paper is authored in the admin portal and
 * answered natively in the app, then graded automatically.
 */
public enum DeliveryMode {
    WEB,
    IN_APP
}
