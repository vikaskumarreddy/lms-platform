package com.institute.lms.converter;

import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;
import java.util.ArrayList;
import java.util.List;

@Converter
public class LongListConverter implements AttributeConverter<List<Long>, String> {

    private static final String SEPARATOR = ",";

    @Override
    public String convertToDatabaseColumn(List<Long> attribute) {
        if (attribute == null || attribute.isEmpty()) {
            return null;
        }
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < attribute.size(); i++) {
            sb.append(attribute.get(i));
            if (i < attribute.size() - 1) {
                sb.append(SEPARATOR);
            }
        }
        return sb.toString();
    }

    @Override
    public List<Long> convertToEntityAttribute(String dbData) {
        if (dbData == null || dbData.isEmpty()) {
            return new ArrayList<>();
        }
        String[] ids = dbData.split(SEPARATOR);
        List<Long> batchIds = new ArrayList<>();
        for (String id : ids) {
            if (!id.trim().isEmpty()) {
                batchIds.add(Long.parseLong(id.trim()));
            }
        }
        return batchIds;
    }
}