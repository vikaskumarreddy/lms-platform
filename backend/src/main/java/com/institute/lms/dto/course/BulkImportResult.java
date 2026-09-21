package com.institute.lms.dto.course;

import java.util.ArrayList;
import java.util.List;

/**
 * Outcome of a bulk import (modules or lessons from a JSON/Excel file).
 *
 * <p>Bulk imports are deliberately tolerant: a row that fails validation is
 * skipped with a human-readable message rather than aborting the whole upload,
 * so one mistyped line never costs an administrator a 200-row spreadsheet. The
 * caller sees both halves of that trade — how much landed ({@code imported}),
 * how much did not ({@code failed}) and exactly why ({@code errors}).
 */
public class BulkImportResult {

    private int imported;
    /** Only used by the module import, where a row may also carry nested lessons. */
    private int lessonsImported;
    private int failed;
    private List<String> errors = new ArrayList<>();

    public BulkImportResult() {
    }

    /** Records one skipped row; {@code message} is shown verbatim to the administrator. */
    public void addError(String message) {
        this.errors.add(message);
        this.failed++;
    }

    public void incrementImported() {
        this.imported++;
    }

    public void incrementLessonsImported() {
        this.lessonsImported++;
    }

    public int getImported() { return imported; }
    public void setImported(int imported) { this.imported = imported; }

    public int getLessonsImported() { return lessonsImported; }
    public void setLessonsImported(int lessonsImported) { this.lessonsImported = lessonsImported; }

    public int getFailed() { return failed; }
    public void setFailed(int failed) { this.failed = failed; }

    public List<String> getErrors() { return errors; }
    public void setErrors(List<String> errors) { this.errors = errors != null ? errors : new ArrayList<>(); }
}
