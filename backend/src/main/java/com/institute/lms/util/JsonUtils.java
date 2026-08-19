package com.institute.lms.util;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Small helpers for the JSON-in-TEXT columns this schema uses — plan entitlements,
 * limit snapshots, feature lists and {@code organizations.settings}.
 *
 * <p>This exists because those columns were previously manipulated with string
 * concatenation and regular expressions (see the original
 * {@code OrganizationService.updateOrgSetting}, whose own comment conceded the
 * approach and which silently corrupted any value containing a comma or a closing
 * brace). Jackson is already on the classpath via {@code spring-boot-starter-web},
 * so there was never a reason to hand-roll it.
 *
 * <p>Reads are deliberately lenient: a malformed or legacy value yields an empty
 * result rather than an exception, because a single bad settings blob should not
 * make a tenant's whole account page fail to load. Writes are strict.
 */
public final class JsonUtils {

    private static final Logger log = LoggerFactory.getLogger(JsonUtils.class);

    private static final ObjectMapper MAPPER = new ObjectMapper();

    private static final TypeReference<Map<String, Object>> MAP_TYPE = new TypeReference<>() { };
    private static final TypeReference<List<String>> STRING_LIST_TYPE = new TypeReference<>() { };

    private JsonUtils() {
    }

    /** Parses a JSON object into a mutable map, or an empty map when absent/invalid. */
    public static Map<String, Object> readMap(String json) {
        if (json == null || json.isBlank()) {
            return new LinkedHashMap<>();
        }
        try {
            Map<String, Object> parsed = MAPPER.readValue(json, MAP_TYPE);
            return parsed != null ? new LinkedHashMap<>(parsed) : new LinkedHashMap<>();
        } catch (Exception e) {
            log.warn("Ignoring malformed JSON object: {}", truncate(json), e);
            return new LinkedHashMap<>();
        }
    }

    /** Parses a JSON array of strings, or an empty list when absent/invalid. */
    public static List<String> readStringList(String json) {
        if (json == null || json.isBlank()) {
            return new ArrayList<>();
        }
        try {
            List<String> parsed = MAPPER.readValue(json, STRING_LIST_TYPE);
            return parsed != null ? new ArrayList<>(parsed) : new ArrayList<>();
        } catch (Exception e) {
            log.warn("Ignoring malformed JSON array: {}", truncate(json), e);
            return new ArrayList<>();
        }
    }

    /** Serialises a value, returning {@code "{}"} rather than throwing on failure. */
    public static String write(Object value) {
        if (value == null) {
            return "{}";
        }
        try {
            return MAPPER.writeValueAsString(value);
        } catch (Exception e) {
            log.error("Failed to serialise {} to JSON", value.getClass().getSimpleName(), e);
            return "{}";
        }
    }

    /**
     * Sets one key in a JSON object column and returns the new JSON, replacing the
     * former regex-based merge. A null value removes the key.
     */
    public static String putKey(String json, String key, Object value) {
        Map<String, Object> map = readMap(json);
        if (value == null) {
            map.remove(key);
        } else {
            map.put(key, value);
        }
        return write(map);
    }

    /** Merges {@code updates} over {@code json}; null values in updates remove keys. */
    public static String mergeKeys(String json, Map<String, Object> updates) {
        if (updates == null || updates.isEmpty()) {
            return json != null && !json.isBlank() ? json : "{}";
        }
        Map<String, Object> map = readMap(json);
        updates.forEach((k, v) -> {
            if (v == null) {
                map.remove(k);
            } else {
                map.put(k, v);
            }
        });
        return write(map);
    }

    // ---- Typed accessors for values read back out of a parsed map -------
    //
    // Values that round-trip through JSON arrive as Integer, Long, Double or
    // String depending on how they were written, so every read coerces rather
    // than casting. A plan limit stored as 200 and one stored as "200" must
    // behave identically.

    /** Coerces a map value to Long; returns {@code fallback} when absent or unparseable. */
    public static Long getLong(Map<String, Object> map, String key, Long fallback) {
        Object raw = map != null ? map.get(key) : null;
        if (raw == null) {
            return fallback;
        }
        if (raw instanceof Number n) {
            return n.longValue();
        }
        try {
            return Long.parseLong(raw.toString().trim());
        } catch (NumberFormatException e) {
            return fallback;
        }
    }

    /** Coerces a map value to BigDecimal; returns {@code fallback} when absent or unparseable. */
    public static BigDecimal getDecimal(Map<String, Object> map, String key, BigDecimal fallback) {
        Object raw = map != null ? map.get(key) : null;
        if (raw == null) {
            return fallback;
        }
        if (raw instanceof BigDecimal bd) {
            return bd;
        }
        if (raw instanceof Number n) {
            return BigDecimal.valueOf(n.doubleValue());
        }
        try {
            return new BigDecimal(raw.toString().trim());
        } catch (NumberFormatException e) {
            return fallback;
        }
    }

    /**
     * Coerces a map value to boolean. Treats a non-zero number as true so that an
     * entitlement written as {@code 1} behaves like {@code true}.
     */
    public static boolean getBoolean(Map<String, Object> map, String key) {
        Object raw = map != null ? map.get(key) : null;
        if (raw == null) {
            return false;
        }
        if (raw instanceof Boolean b) {
            return b;
        }
        if (raw instanceof Number n) {
            return n.doubleValue() != 0d;
        }
        return Boolean.parseBoolean(raw.toString().trim());
    }

    public static String getString(Map<String, Object> map, String key, String fallback) {
        Object raw = map != null ? map.get(key) : null;
        return raw != null ? raw.toString() : fallback;
    }

    /** True when {@code json} is an array containing {@code value}. Empty/absent means "no restriction". */
    public static boolean listContains(String json, String value) {
        if (json == null || json.isBlank()) {
            return true;
        }
        List<String> values = readStringList(json);
        return values.isEmpty() || values.contains(value);
    }

    public static List<String> emptyList() {
        return Collections.emptyList();
    }

    private static String truncate(String s) {
        return s.length() <= 200 ? s : s.substring(0, 200) + "...";
    }
}
