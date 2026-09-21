package com.institute.lms.util;

import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.BooleanNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.institute.lms.dto.course.LessonRequest;
import com.institute.lms.dto.course.ModuleRequest;
import com.institute.lms.exception.BadRequestException;
import org.apache.poi.ss.usermodel.Cell;
import org.apache.poi.ss.usermodel.DataFormatter;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Workbook;
import org.apache.poi.ss.usermodel.WorkbookFactory;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/**
 * Reads a bulk-import file into the very same request objects the manual create
 * forms post ({@link ModuleRequest} / {@link LessonRequest}), so an imported
 * module or lesson is indistinguishable from one typed in by hand — same
 * defaults, same self-hosted video/PDF resolution, same validation downstream.
 *
 * <p>Two formats are accepted:
 * <ul>
 *   <li><b>JSON</b> — an array of objects (or a single object, or an object
 *       wrapping a {@code modules}/{@code lessons} array) using the same
 *       camelCase field names as the admin API. {@code order_index}-style keys
 *       are accepted as well.</li>
 *   <li><b>Excel</b> ({@code .xlsx}/{@code .xls}) — the first sheet, with the
 *       first non-empty row as the header. Column names are matched ignoring
 *       case, spaces, dashes and underscores, so "Order Index", "order_index"
 *       and "orderIndex" all work. A {@code Lessons} column may hold a JSON
 *       array for module imports.</li>
 * </ul>
 *
 * <p>Row-level problems never throw: the row comes back as a
 * {@link ParsedRow} carrying a message, so a single malformed line does not
 * cost the administrator the whole upload. Only genuinely unreadable input
 * (wrong extension, corrupt workbook, empty file, too many rows) raises
 * {@link BadRequestException}.
 */
public final class BulkImportParser {

    /** A paste of an entire spreadsheet in one request would be a footgun, not a feature. */
    public static final int MAX_ROWS = 500;

    private static final ObjectMapper JSON = new ObjectMapper()
            .configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);

    private static final DataFormatter FORMATTER = new DataFormatter();

    private BulkImportParser() {
    }

    /**
     * One row read from the file. Exactly one of {@code value} / {@code error} is
     * set: a value means the row parsed and can be imported, an error means the
     * row was skipped with {@code error} explaining why (shown to the admin).
     */
    public static class ParsedRow<T> {
        private final int number;
        private final T value;
        private final String error;

        private ParsedRow(int number, T value, String error) {
            this.number = number;
            this.value = value;
            this.error = error;
        }

        static <T> ParsedRow<T> ok(int number, T value) {
            return new ParsedRow<>(number, value, null);
        }

        static <T> ParsedRow<T> failed(int number, String error) {
            return new ParsedRow<>(number, null, error);
        }

        /** 1-based row number (spreadsheet row / JSON array position) used in messages. */
        public int getNumber() { return number; }
        public T getValue() { return value; }
        public String getError() { return error; }
    }

    /** A parsed lesson plus the optional module it should be attached to. */
    public static class LessonRow {
        private final LessonRequest request;
        private final String moduleRef;

        public LessonRow(LessonRequest request, String moduleRef) {
            this.request = request;
            this.moduleRef = moduleRef;
        }

        public LessonRequest getRequest() { return request; }

        /**
         * Value of the optional "Module" column — the title or order index of the
         * module this lesson belongs to. {@code null} means "the module the import
         * was started from".
         */
        public String getModuleRef() { return moduleRef; }
    }
    // ─────────────────────────────────────────────────────────────
    // Entry points
    // ─────────────────────────────────────────────────────────────

    /** Parses a module import file (JSON array or Excel sheet) into module requests. */
    public static List<ParsedRow<ModuleRequest>> parseModules(MultipartFile file) {
        requireSupportedFile(file);
        return isJson(file) ? jsonModules(file) : excelModules(file);
    }

    /** Parses a lesson import file (JSON array or Excel sheet) into lesson rows. */
    public static List<ParsedRow<LessonRow>> parseLessons(MultipartFile file) {
        requireSupportedFile(file);
        return isJson(file) ? jsonLessons(file) : excelLessons(file);
    }

    // ─────────────────────────────────────────────────────────────
    // JSON
    // ─────────────────────────────────────────────────────────────

    private static List<ParsedRow<ModuleRequest>> jsonModules(MultipartFile file) {
        List<JsonNode> nodes = limitedRows(readJson(file), "modules");
        List<ParsedRow<ModuleRequest>> rows = new ArrayList<>();
        int number = 0;
        for (JsonNode node : nodes) {
            number++;
            try {
                rows.add(ParsedRow.ok(number, JSON.treeToValue(node, ModuleRequest.class)));
            } catch (Exception e) {
                rows.add(ParsedRow.failed(number, readable(e)));
            }
        }
        return nonEmpty(rows);
    }

    private static List<ParsedRow<LessonRow>> jsonLessons(MultipartFile file) {
        List<JsonNode> nodes = limitedRows(readJson(file), "lessons");
        List<ParsedRow<LessonRow>> rows = new ArrayList<>();
        int number = 0;
        for (JsonNode node : nodes) {
            number++;
            try {
                rows.add(ParsedRow.ok(number,
                        new LessonRow(JSON.treeToValue(node, LessonRequest.class), moduleRef(node))));
            } catch (Exception e) {
                rows.add(ParsedRow.failed(number, readable(e)));
            }
        }
        return nonEmpty(rows);
    }

    /** Row nodes for a JSON import, rejecting a file that exceeds {@link #MAX_ROWS}. */
    private static List<JsonNode> limitedRows(JsonNode root, String arrayKey) {
        List<JsonNode> nodes = rowNodes(root, arrayKey);
        requireRowLimit(nodes.size());
        return nodes;
    }

    /** The wrapped array of rows: the document itself, or its {@code modules}/{@code lessons} key. */
    private static List<JsonNode> rowNodes(JsonNode root, String arrayKey) {
        if (root == null || root.isNull()) {
            throw new BadRequestException("The file is empty.");
        }
        JsonNode candidate = root;
        if (root.isObject()) {
            JsonNode nested = root.get(arrayKey);
            if (nested != null) {
                candidate = nested;
            }
        }
        List<JsonNode> nodes = new ArrayList<>();
        if (candidate.isArray()) {
            for (JsonNode child : candidate) {
                if (child != null && !child.isNull() && !(child.isObject() && child.isEmpty())) {
                    nodes.add(child);
                }
            }
        } else if (candidate.isObject()) {
            if (!candidate.isEmpty()) {
                nodes.add(candidate);
            }
        } else {
            throw new BadRequestException("The file must be a JSON array of objects, or an object holding a \""
                    + arrayKey + "\" array.");
        }
        return nodes;
    }

    private static JsonNode readJson(MultipartFile file) {
        try {
            byte[] bytes = file.getBytes();
            int start = (bytes.length >= 3 && (bytes[0] & 0xFF) == 0xEF
                    && (bytes[1] & 0xFF) == 0xBB && (bytes[2] & 0xFF) == 0xBF) ? 3 : 0;
            JsonNode root = JSON.readTree(new String(bytes, start, bytes.length - start, StandardCharsets.UTF_8));
            if (root == null) {
                throw new BadRequestException("The file is empty.");
            }
            // Keys are normalised so a hand-written file using order_index /
            // "Order Index" works exactly like one using orderIndex.
            return normalizeKeys(root);
        } catch (IOException e) {
            throw new BadRequestException("The JSON file could not be read: " + readable(e));
        }
    }

    private static JsonNode normalizeKeys(JsonNode node) {
        if (node.isObject()) {
            ObjectNode out = JSON.createObjectNode();
            node.fields().forEachRemaining(entry -> {
                String key = toCamel(entry.getKey());
                out.set(key, coerceBoolean(key, normalizeKeys(entry.getValue())));
            });
            return out;
        }
        if (node.isArray()) {
            ArrayNode out = JSON.createArrayNode();
            for (JsonNode child : node) {
                out.add(normalizeKeys(child));
            }
            return out;
        }
        return node;
    }

    /** Boolean fields accept the same yes/no spellings in JSON as in a spreadsheet cell. */
    private static JsonNode coerceBoolean(String key, JsonNode value) {
        if (!("isLocked".equals(key) || "isMandatory".equals(key)) || !value.isTextual()) {
            return value;
        }
        switch (value.asText().trim().toLowerCase(Locale.ROOT)) {
            case "true": case "yes": case "y": case "1": return BooleanNode.TRUE;
            case "false": case "no": case "n": case "0": return BooleanNode.FALSE;
            default: return value;
        }
    }

    /** {@code order_index} / {@code "Order Index"} → {@code orderIndex}; {@code orderIndex} is left alone. */
    private static String toCamel(String raw) {
        String[] parts = raw.trim().split("[^A-Za-z0-9]+");
        StringBuilder out = new StringBuilder();
        for (String part : parts) {
            if (part.isEmpty()) {
                continue;
            }
            if (out.length() == 0) {
                out.append(parts.length == 1
                        ? Character.toLowerCase(part.charAt(0)) + part.substring(1)
                        : part.toLowerCase(Locale.ROOT));
            } else {
                out.append(Character.toUpperCase(part.charAt(0)))
                        .append(part.substring(1).toLowerCase(Locale.ROOT));
            }
        }
        return out.toString();
    }

    /** First non-blank "which module is this lesson for" key on a JSON lesson row. */
    private static String moduleRef(JsonNode node) {
        for (String key : new String[]{"moduleRef", "moduleTitle", "module", "moduleOrderIndex", "moduleId"}) {
            JsonNode value = node.get(key);
            if (value != null && value.isValueNode() && !value.asText().isBlank()) {
                return value.asText().trim();
            }
        }
        return null;
    }
    // ─────────────────────────────────────────────────────────────
    // Excel
    // ─────────────────────────────────────────────────────────────

    private static List<ParsedRow<ModuleRequest>> excelModules(MultipartFile file) {
        try (Workbook workbook = openWorkbook(file)) {
            Iterator<Row> sheetRows = workbook.getSheetAt(0).iterator();
            Row header = nextDataRow(sheetRows);
            if (header == null) {
                throw new BadRequestException("The spreadsheet does not contain any rows to import.");
            }
            Map<String, Integer> columns = headerColumns(header);
            requireColumn(columns, "Title", "title", "moduletitle");
            requireColumn(columns, "Description", "description", "moduledescription", "desc");

            List<ParsedRow<ModuleRequest>> parsed = new ArrayList<>();
            while (sheetRows.hasNext()) {
                Row row = sheetRows.next();
                if (isBlankRow(row)) {
                    continue;
                }
                ensureRoom(parsed);
                int number = row.getRowNum() + 1;
                try {
                    parsed.add(ParsedRow.ok(number, moduleFromRow(row, columns)));
                } catch (RuntimeException e) {
                    parsed.add(ParsedRow.failed(number, readable(e)));
                }
            }
            return nonEmpty(parsed);
        } catch (IOException e) {
            throw new BadRequestException("The Excel file could not be read: " + readable(e));
        }
    }

    private static List<ParsedRow<LessonRow>> excelLessons(MultipartFile file) {
        try (Workbook workbook = openWorkbook(file)) {
            Iterator<Row> sheetRows = workbook.getSheetAt(0).iterator();
            Row header = nextDataRow(sheetRows);
            if (header == null) {
                throw new BadRequestException("The spreadsheet does not contain any rows to import.");
            }
            Map<String, Integer> columns = headerColumns(header);
            requireColumn(columns, "Title", "title", "lessontitle");

            List<ParsedRow<LessonRow>> parsed = new ArrayList<>();
            while (sheetRows.hasNext()) {
                Row row = sheetRows.next();
                if (isBlankRow(row)) {
                    continue;
                }
                ensureRoom(parsed);
                int number = row.getRowNum() + 1;
                try {
                    parsed.add(ParsedRow.ok(number, lessonFromRow(row, columns)));
                } catch (RuntimeException e) {
                    parsed.add(ParsedRow.failed(number, readable(e)));
                }
            }
            return nonEmpty(parsed);
        } catch (IOException e) {
            throw new BadRequestException("The Excel file could not be read: " + readable(e));
        }
    }
    /** Reads one spreadsheet row into the same DTO the "Add Module" form posts. */
    private static ModuleRequest moduleFromRow(Row row, Map<String, Integer> columns) {
        ModuleRequest request = new ModuleRequest();
        request.setTitle(text(row, col(columns, "title", "moduletitle")));
        request.setDescription(text(row, col(columns, "description", "moduledescription", "desc")));
        request.setIcon(text(row, col(columns, "icon", "emoji")));
        request.setColor(text(row, col(columns, "color", "colour")));
        request.setOrderIndex(wholeNumber(row, col(columns, "orderindex", "index", "order"), "Order index"));
        Boolean locked = yesNo(row, col(columns, "islocked", "locked"));
        if (locked != null) {
            request.setIsLocked(locked);
        }
        // Optional: a whole module — lessons included — can be described in one
        // JSON cell, which is the only way a spreadsheet can carry a nested list.
        String lessons = text(row, col(columns, "lessons", "lessonjson"));
        if (lessons != null) {
            request.setLessons(lessonsFromJson(lessons));
        }
        return request;
    }

    /** Reads one spreadsheet row into the same DTO the "Add Lesson" form posts. */
    private static LessonRow lessonFromRow(Row row, Map<String, Integer> columns) {
        LessonRequest request = new LessonRequest();
        request.setTitle(text(row, col(columns, "title", "lessontitle")));
        request.setHeading(text(row, col(columns, "heading")));
        request.setContent(text(row, col(columns, "content")));
        request.setVideoUrl(text(row, col(columns, "videourl", "video")));
        request.setVideoSource(upper(text(row, col(columns, "videosource", "videosourcetype"))));
        request.setVideoId(longNumber(row, col(columns, "videoid", "videomediaid"), "Video ID"));
        request.setThumbnailUrl(text(row, col(columns, "thumbnailurl", "thumbnail")));
        request.setPdfNotesUrl(text(row, col(columns, "pdfnotesurl", "pdfurl", "pdf")));
        request.setPdfSource(upper(text(row, col(columns, "pdfsource", "pdfsourcetype"))));
        request.setPdfNoteId(longNumber(row, col(columns, "pdfnoteid", "pdfmediaid", "pdfnote"), "PDF note ID"));
        request.setOrderIndex(wholeNumber(row, col(columns, "orderindex", "index", "order"), "Order index"));
        request.setDurationMinutes(wholeNumber(row, col(columns, "durationminutes", "duration"), "Duration"));
        Boolean locked = yesNo(row, col(columns, "islocked", "locked"));
        if (locked != null) {
            request.setIsLocked(locked);
        }
        Boolean mandatory = yesNo(row, col(columns, "ismandatory", "mandatory"));
        if (mandatory != null) {
            request.setIsMandatory(mandatory);
        }
        String moduleRef = text(row, col(columns, "module", "moduletitle",
                "moduleindex", "moduleorderindex", "moduleid"));
        return new LessonRow(request, moduleRef);
    }

    /** Parses the "Lessons" cell of a module row: a JSON array of lesson objects. */
    private static List<LessonRequest> lessonsFromJson(String json) {
        try {
            List<JsonNode> nodes = rowNodes(normalizeKeys(JSON.readTree(json)), "lessons");
            List<LessonRequest> lessons = new ArrayList<>();
            for (JsonNode node : nodes) {
                lessons.add(JSON.treeToValue(node, LessonRequest.class));
            }
            return lessons;
        } catch (IOException e) {
            throw new BadRequestException("the Lessons cell is not valid JSON (" + readable(e) + ")");
        }
    }
    // ─────────────────────────────────────────────────────────────
    // Header & cell helpers
    // ─────────────────────────────────────────────────────────────

    private static Workbook openWorkbook(MultipartFile file) {
        // POI reads the stream fully up front, so closing it here is safe.
        try (InputStream in = file.getInputStream()) {
            return WorkbookFactory.create(in);
        } catch (IOException | RuntimeException e) {
            throw new BadRequestException("The Excel file could not be read: " + readable(e));
        }
    }

    /** First row that carries any value — spreadsheets often start with blank spacer rows. */
    private static Row nextDataRow(Iterator<Row> rows) {
        while (rows.hasNext()) {
            Row row = rows.next();
            if (!isBlankRow(row)) {
                return row;
            }
        }
        return null;
    }

    private static boolean isBlankRow(Row row) {
        if (row == null) {
            return true;
        }
        for (int i = row.getFirstCellNum(); i < row.getLastCellNum(); i++) {
            Cell cell = row.getCell(i);
            if (cell != null && !FORMATTER.formatCellValue(cell).trim().isEmpty()) {
                return false;
            }
        }
        return true;
    }

    /** Maps each header cell to its column index, ignoring case/spaces/underscores. */
    private static Map<String, Integer> headerColumns(Row header) {
        Map<String, Integer> columns = new HashMap<>();
        for (int i = header.getFirstCellNum(); i < header.getLastCellNum(); i++) {
            Cell cell = header.getCell(i);
            if (cell == null) {
                continue;
            }
            String name = normalizeHeader(FORMATTER.formatCellValue(cell));
            if (!name.isEmpty()) {
                columns.putIfAbsent(name, i);
            }
        }
        return columns;
    }

    private static String normalizeHeader(String raw) {
        return raw.toLowerCase(Locale.ROOT).replaceAll("[^a-z0-9]", "");
    }

    /** Column index for the first matching alias, or {@code null} when the column is absent. */
    private static Integer col(Map<String, Integer> columns, String... aliases) {
        for (String alias : aliases) {
            Integer index = columns.get(normalizeHeader(alias));
            if (index != null) {
                return index;
            }
        }
        return null;
    }

    private static void requireColumn(Map<String, Integer> columns, String displayName, String... aliases) {
        if (col(columns, aliases) == null) {
            throw new BadRequestException("The spreadsheet needs a \"" + displayName + "\" column.");
        }
    }

    private static String text(Row row, Integer index) {
        if (index == null) {
            return null;
        }
        Cell cell = row.getCell(index);
        if (cell == null) {
            return null;
        }
        String value = FORMATTER.formatCellValue(cell).trim();
        return value.isEmpty() ? null : value;
    }

    private static Integer wholeNumber(Row row, Integer index, String label) {
        String raw = text(row, index);
        if (raw == null) {
            return null;
        }
        try {
            double value = Double.parseDouble(raw);
            if (value != Math.rint(value)) {
                throw new NumberFormatException();
            }
            return (int) value;
        } catch (NumberFormatException e) {
            throw new BadRequestException(label + " \"" + raw + "\" is not a whole number.");
        }
    }

    private static Long longNumber(Row row, Integer index, String label) {
        Integer value = wholeNumber(row, index, label);
        return value == null ? null : value.longValue();
    }

    /** Accepts the yes/no spellings people actually type in spreadsheets. */
    private static Boolean yesNo(Row row, Integer index) {
        String raw = text(row, index);
        if (raw == null) {
            return null;
        }
        switch (raw.toLowerCase(Locale.ROOT)) {
            case "true": case "yes": case "y": case "1": return Boolean.TRUE;
            case "false": case "no": case "n": case "0": return Boolean.FALSE;
            default: throw new BadRequestException("\"" + raw + "\" is not a yes/no value.");
        }
    }

    private static String upper(String value) {
        return value == null ? null : value.toUpperCase(Locale.ROOT);
    }
    // ─────────────────────────────────────────────────────────────
    // Shared guards
    // ─────────────────────────────────────────────────────────────

    private static void requireSupportedFile(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new BadRequestException("Choose a JSON or Excel (.xlsx/.xls) file to import.");
        }
        if (!isJson(file) && !isExcel(file)) {
            throw new BadRequestException("Unsupported file \"" + file.getOriginalFilename()
                    + "\". Upload a .json, .xlsx or .xls file.");
        }
    }

    private static boolean isJson(MultipartFile file) {
        String type = contentType(file);
        return fileName(file).endsWith(".json") || type.contains("json");
    }

    private static boolean isExcel(MultipartFile file) {
        String name = fileName(file);
        String type = contentType(file);
        return name.endsWith(".xlsx") || name.endsWith(".xls") || name.endsWith(".xlsm")
                || type.contains("spreadsheet") || type.contains("excel");
    }

    private static String fileName(MultipartFile file) {
        String name = file != null ? file.getOriginalFilename() : null;
        return name == null ? "" : name.toLowerCase(Locale.ROOT);
    }

    private static String contentType(MultipartFile file) {
        String type = file != null ? file.getContentType() : null;
        return type == null ? "" : type.toLowerCase(Locale.ROOT);
    }

    private static void ensureRoom(List<?> parsed) {
        requireRowLimit(parsed.size() + 1);
    }

    private static void requireRowLimit(int size) {
        if (size > MAX_ROWS) {
            throw new BadRequestException("Too many rows in one file (limit " + MAX_ROWS
                    + "). Split the upload into smaller files.");
        }
    }

    private static <T> List<ParsedRow<T>> nonEmpty(List<ParsedRow<T>> rows) {
        if (rows.isEmpty()) {
            throw new BadRequestException("The file does not contain any rows to import.");
        }
        return rows;
    }

    /** First line of a thrown message, capped — Jackson's parse errors are multi-line essays. */
    private static String readable(Throwable e) {
        String message = e.getMessage() == null || e.getMessage().isBlank()
                ? e.getClass().getSimpleName() : e.getMessage();
        int newline = message.indexOf('\n');
        if (newline > 0) {
            message = message.substring(0, newline);
        }
        return message.length() > 200 ? message.substring(0, 200) + "..." : message;
    }
}
