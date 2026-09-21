package com.institute.lms.util;

import com.institute.lms.dto.course.ModuleRequest;
import com.institute.lms.exception.BadRequestException;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockMultipartFile;

import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Covers the file-reading half of the module/lesson bulk import: JSON and Excel
 * both have to produce the same request objects the manual forms post, a bad row
 * must be reported instead of aborting the upload, and unreadable input must fail
 * loudly.
 *
 * <p>Runs without a database or Spring context. It also drops the workbooks it
 * builds into {@code target/bulk-import-samples/} so the exact same files can be
 * replayed against a running backend by hand.
 */
class BulkImportParserTest {

    private static final String XLSX = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";

    // ── JSON ─────────────────────────────────────────────────────

    @Test
    void jsonArrayAcceptsCamelCaseAndSnakeCaseKeys() {
        String json = """
                [
                  { "title": "Module A", "description": "First", "order_index": 4, "is_locked": "yes" },
                  { "title": "Module B", "description": "Second", "orderIndex": 5, "isLocked": false,
                    "lessons": [ { "title": "Lesson A1", "durationMinutes": 20 } ] }
                ]
                """;
        List<BulkImportParser.ParsedRow<ModuleRequest>> rows = BulkImportParser.parseModules(jsonFile(json));

        assertEquals(2, rows.size());
        assertNull(rows.get(0).getError());
        assertEquals("Module A", rows.get(0).getValue().getTitle());
        assertEquals(4, rows.get(0).getValue().getOrderIndex());
        assertEquals(Boolean.TRUE, rows.get(0).getValue().getIsLocked());

        assertEquals(1, rows.get(1).getValue().getLessons().size());
        assertEquals("Lesson A1", rows.get(1).getValue().getLessons().get(0).getTitle());
        assertEquals(20, rows.get(1).getValue().getLessons().get(0).getDurationMinutes());
    }

    @Test
    void jsonObjectWrappingModulesKeyIsAccepted() {
        String json = """
                { "modules": [ { "title": "Only", "description": "One row" } ] }
                """;
        List<BulkImportParser.ParsedRow<ModuleRequest>> rows = BulkImportParser.parseModules(jsonFile(json));
        assertEquals(1, rows.size());
        assertEquals("Only", rows.get(0).getValue().getTitle());
    }

    @Test
    void unparsableRowIsReportedWhileOthersSurvive() {
        String json = """
                [
                  { "title": "Good", "description": "Fine" },
                  { "title": "Bad", "description": "Broken", "orderIndex": "not-a-number" }
                ]
                """;
        List<BulkImportParser.ParsedRow<ModuleRequest>> rows = BulkImportParser.parseModules(jsonFile(json));

        assertEquals(2, rows.size());
        assertNull(rows.get(0).getError());
        assertEquals(2, rows.get(1).getNumber());
        assertNotNull(rows.get(1).getError());
        assertNull(rows.get(1).getValue());
    }

    @Test
    void emptyJsonArrayIsRejected() {
        assertThrows(BadRequestException.class, () -> BulkImportParser.parseModules(jsonFile("[]")));
    }

    @Test
    void lessonRowsCarryTheModuleReference() {
        String json = """
                [ { "title": "Routed lesson", "moduleTitle": "Module B", "videoSource": "SELF", "videoId": 42 } ]
                """;
        List<BulkImportParser.ParsedRow<BulkImportParser.LessonRow>> rows =
                BulkImportParser.parseLessons(jsonFile(json));

        assertEquals("Module B", rows.get(0).getValue().getModuleRef());
        assertEquals(42L, rows.get(0).getValue().getRequest().getVideoId());
        assertEquals("SELF", rows.get(0).getValue().getRequest().getVideoSource());
    }
    // ── Excel ────────────────────────────────────────────────────

    @Test
    void excelColumnsAreMatchedLooselyAndLessonsCellIsParsed() throws Exception {
        List<BulkImportParser.ParsedRow<ModuleRequest>> rows = BulkImportParser.parseModules(workbook(moduleSheet()));
        sample("modules-sample.xlsx", moduleSheet());

        assertEquals(1, rows.size());
        ModuleRequest module = rows.get(0).getValue();
        assertEquals("Imported Module", module.getTitle());
        assertEquals("Imported description", module.getDescription());
        assertEquals("📘", module.getIcon());
        assertEquals("#4F46E5", module.getColor());
        assertEquals(3, module.getOrderIndex());
        assertEquals(Boolean.TRUE, module.getIsLocked());
        assertEquals(1, module.getLessons().size());
        assertEquals("Nested lesson", module.getLessons().get(0).getTitle());
        assertTrue(Files.exists(Path.of("target", "bulk-import-samples", "modules-sample.xlsx")));
    }

    @Test
    void lessonSheetParsesDefaultsAndFlags() throws Exception {
        List<BulkImportParser.ParsedRow<BulkImportParser.LessonRow>> rows =
                BulkImportParser.parseLessons(workbook(lessonSheet()));
        sample("lessons-sample.xlsx", lessonSheet());

        assertEquals(2, rows.size());
        var first = rows.get(0).getValue();
        assertEquals("Lesson one", first.getRequest().getTitle());
        assertEquals("Heading one", first.getRequest().getHeading());
        assertEquals(Boolean.TRUE, first.getRequest().getIsLocked());
        assertEquals(Boolean.FALSE, first.getRequest().getIsMandatory());
        assertEquals(12, first.getRequest().getDurationMinutes());
        assertEquals("Module two", first.getModuleRef());
        assertEquals(7L, first.getRequest().getVideoId());
        assertEquals("SELF", first.getRequest().getVideoSource());

        // A row carrying only the mandatory Title column still parses.
        var second = rows.get(1).getValue();
        assertEquals("Lesson two", second.getRequest().getTitle());
        assertNull(second.getRequest().getOrderIndex());
        assertNull(second.getModuleRef());
    }

    @Test
    void spreadsheetWithoutMandatoryColumnsIsRejected() {
        assertThrows(BadRequestException.class, () -> BulkImportParser.parseModules(workbook(sheet("Notes",
                new String[]{"Something"}, new String[]{"value"}))));
    }

    @Test
    void badCellValueFailsOnlyThatRow() {
        byte[] book = sheet("Modules",
                new String[]{"Title", "Description", "Order Index"},
                new String[]{"Ok module", "Fine", "2"},
                new String[]{"Bad module", "Fine", "two"});
        List<BulkImportParser.ParsedRow<ModuleRequest>> rows = BulkImportParser.parseModules(workbook(book));

        assertNull(rows.get(0).getError());
        assertNotNull(rows.get(1).getError());
        assertTrue(rows.get(1).getError().contains("Order index"));
    }
    // ── Guards ───────────────────────────────────────────────────

    @Test
    void unsupportedAndEmptyFilesAreRejected() {
        MockMultipartFile csv = new MockMultipartFile("file", "rows.csv", "text/csv",
                "a,b".getBytes(StandardCharsets.UTF_8));
        assertThrows(BadRequestException.class, () -> BulkImportParser.parseModules(csv));

        MockMultipartFile empty = new MockMultipartFile("file", "rows.json", "application/json", new byte[0]);
        assertThrows(BadRequestException.class, () -> BulkImportParser.parseModules(empty));
    }

    @Test
    void moreThanTheRowLimitIsRejected() {
        StringBuilder json = new StringBuilder("[");
        for (int i = 0; i <= BulkImportParser.MAX_ROWS; i++) {
            json.append(i == 0 ? "" : ",").append("{\"title\":\"m").append(i).append("\",\"description\":\"d\"}");
        }
        json.append("]");
        String body = json.toString();
        assertThrows(BadRequestException.class, () -> BulkImportParser.parseModules(jsonFile(body)));
    }

    // ── Helpers ──────────────────────────────────────────────────

    private static MockMultipartFile jsonFile(String body) {
        return new MockMultipartFile("file", "import.json", "application/json",
                body.getBytes(StandardCharsets.UTF_8));
    }

    private static MockMultipartFile workbook(byte[] bytes) {
        return new MockMultipartFile("file", "import.xlsx", XLSX, bytes);
    }

    private static byte[] moduleSheet() {
        return sheet("Modules",
                new String[]{"Title", "Description", "Icon", "Colour", "Order Index", "Is Locked", "Lessons"},
                new String[]{"Imported Module", "Imported description", "📘", "#4F46E5", "3", "yes",
                        "[{\"title\":\"Nested lesson\",\"durationMinutes\":15}]"});
    }

    private static byte[] lessonSheet() {
        return sheet("Lessons",
                new String[]{"Module", "Title", "Heading", "Order Index", "Duration", "Is Locked", "Is Mandatory",
                        "Video Source", "Video ID"},
                new String[]{"Module two", "Lesson one", "Heading one", "0", "12", "yes", "no", "SELF", "7"},
                new String[]{null, "Lesson two"});
    }

    /** Builds a one-sheet workbook whose first row is the header. */
    private static byte[] sheet(String name, String[] header, String[]... dataRows) {
        try (XSSFWorkbook workbook = new XSSFWorkbook(); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            Sheet sheet = workbook.createSheet(name);
            Row headerRow = sheet.createRow(0);
            for (int i = 0; i < header.length; i++) {
                headerRow.createCell(i).setCellValue(header[i]);
            }
            for (int r = 0; r < dataRows.length; r++) {
                Row row = sheet.createRow(r + 1);
                String[] values = dataRows[r];
                for (int c = 0; c < values.length; c++) {
                    if (values[c] != null) {
                        row.createCell(c).setCellValue(values[c]);
                    }
                }
            }
            workbook.write(out);
            return out.toByteArray();
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }

    /** Also writes the workbook to target/bulk-import-samples so it can be uploaded by hand. */
    private static void sample(String fileName, byte[] bytes) throws Exception {
        Path dir = Path.of("target", "bulk-import-samples");
        Files.createDirectories(dir);
        Files.write(dir.resolve(fileName), bytes);
    }
}
