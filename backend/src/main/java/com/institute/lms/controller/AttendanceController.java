package com.institute.lms.controller;

import com.institute.lms.entity.Attendance;
import com.institute.lms.entity.Event;
import com.institute.lms.entity.User;
import com.institute.lms.repository.AttendanceRepository;
import com.institute.lms.repository.EventRepository;
import com.institute.lms.repository.UserRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/attendance")
public class AttendanceController {

    private final AttendanceRepository attendanceRepository;
    private final EventRepository eventRepository;
    private final UserRepository userRepository;

    public AttendanceController(AttendanceRepository attendanceRepository, EventRepository eventRepository,
                                 UserRepository userRepository) {
        this.attendanceRepository = attendanceRepository;
        this.eventRepository = eventRepository;
        this.userRepository = userRepository;
    }

    /** All attendance records for an event, including students who are not yet marked. */
    @GetMapping("/event/{eventId}")
    public ResponseEntity<Map<String, Object>> getAttendanceForEvent(@PathVariable Long eventId) {
        Event event = eventRepository.findById(eventId).orElse(null);
        if (event == null) return ResponseEntity.notFound().build();

        List<User> students = event.getBatchId() != null
                ? userRepository.findByRoleAndBatchId(User.UserRole.STUDENT, event.getBatchId())
                : userRepository.findByRole(User.UserRole.STUDENT);

        List<Attendance> existing = attendanceRepository.findByEventId(eventId);
        Map<Long, Attendance> byUser = new LinkedHashMap<>();
        for (Attendance a : existing) {
            if (a.getUser() != null) byUser.put(a.getUser().getId(), a);
        }

        List<Map<String, Object>> rows = new java.util.ArrayList<>();
        for (User student : students) {
            Attendance a = byUser.get(student.getId());
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("attendanceId", a != null ? a.getId() : null);
            row.put("userId", student.getId());
            row.put("userName", student.getName());
            row.put("present", a != null ? a.getPresent() : false);
            row.put("remarks", a != null ? a.getRemarks() : null);
            rows.add(row);
        }

        Map<String, Object> response = new LinkedHashMap<>();
        response.put("eventId", eventId);
        response.put("eventTitle", event.getTitle());
        response.put("students", rows);
        return ResponseEntity.ok(response);
    }

    /** Bulk mark attendance for an event. Body: { "records": [ {"userId":1,"present":true,"remarks":""} ] } */
    @PostMapping("/event/{eventId}/mark")
    public ResponseEntity<List<Attendance>> markAttendance(@PathVariable Long eventId, @RequestBody Map<String, Object> body) {
        Event event = eventRepository.findById(eventId).orElseThrow(() -> new RuntimeException("Event not found"));
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> records = (List<Map<String, Object>>) body.get("records");
        List<Attendance> saved = new java.util.ArrayList<>();
        if (records != null) {
            for (Map<String, Object> record : records) {
                Long userId = ((Number) record.get("userId")).longValue();
                Boolean present = Boolean.TRUE.equals(record.get("present"));
                String remarks = record.get("remarks") != null ? record.get("remarks").toString() : null;

                User user = userRepository.findById(userId).orElse(null);
                if (user == null) continue;

                Attendance attendance = attendanceRepository.findByUserIdAndEventId(userId, eventId)
                        .orElseGet(Attendance::new);
                attendance.setUser(user);
                attendance.setEvent(event);
                attendance.setPresent(present);
                attendance.setRemarks(remarks);
                saved.add(attendanceRepository.save(attendance));
            }
        }
        return ResponseEntity.ok(saved);
    }

    /** Attendance history + summary percentage for a student. */
    @GetMapping("/student/{studentId}")
    public ResponseEntity<Map<String, Object>> getAttendanceForStudent(@PathVariable Long studentId) {
        List<Attendance> records = attendanceRepository.findByUserId(studentId);
        long total = records.size();
        long present = records.stream().filter(a -> Boolean.TRUE.equals(a.getPresent())).count();
        double percentage = total > 0 ? (present * 100.0 / total) : 0.0;

        List<Map<String, Object>> history = new java.util.ArrayList<>();
        for (Attendance a : records) {
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("eventId", a.getEvent() != null ? a.getEvent().getId() : null);
            item.put("eventTitle", a.getEvent() != null ? a.getEvent().getTitle() : null);
            item.put("eventType", a.getEvent() != null ? a.getEvent().getEventType() : null);
            item.put("startTime", a.getEvent() != null ? a.getEvent().getStartTime() : null);
            item.put("present", a.getPresent());
            item.put("remarks", a.getRemarks());
            history.add(item);
        }

        Map<String, Object> response = new LinkedHashMap<>();
        response.put("totalEvents", total);
        response.put("presentCount", present);
        response.put("absentCount", total - present);
        response.put("percentage", Math.round(percentage * 100.0) / 100.0);
        response.put("history", history);
        return ResponseEntity.ok(response);
    }
}
