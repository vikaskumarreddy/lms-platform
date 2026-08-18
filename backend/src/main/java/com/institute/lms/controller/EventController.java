package com.institute.lms.controller;

import com.institute.lms.entity.Event;
import com.institute.lms.repository.EventRepository;
import com.institute.lms.util.UserContext;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/events")
public class EventController {

    private final EventRepository eventRepository;
    private final UserContext userContext;

    public EventController(EventRepository eventRepository, UserContext userContext) {
        this.eventRepository = eventRepository;
        this.userContext = userContext;
    }

    @GetMapping
    public List<Event> getAllEvents() {
        // Faculty are scoped to events for their own batch (plus shared events with no batch).
        if (userContext.isFaculty()) {
            Long batchId = userContext.facultyBatchId();
            return batchId != null ? eventRepository.findByBatchIdIsNullOrBatchId(batchId) : eventRepository.findAll();
        }
        return eventRepository.findAll();
    }

    @GetMapping("/{id}")
    public ResponseEntity<Event> getEventById(@PathVariable Long id) {
        return eventRepository.findById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @GetMapping("/batch/{batchId}")
    public List<Event> getEventsByBatch(@PathVariable Long batchId) {
        return eventRepository.findByBatchIdIsNullOrBatchId(batchId);
    }

    @GetMapping("/plan/{planId}")
    public List<Event> getEventsByPlan(@PathVariable Long planId) {
        return eventRepository.findByPlanId(planId);
    }

    @PostMapping
    public Event createEvent(@RequestBody Event event) {
        if (event.getAttendanceRequired() == null) event.setAttendanceRequired(true);
        return eventRepository.save(event);
    }

    @PutMapping("/{id}")
    public ResponseEntity<Event> updateEvent(@PathVariable Long id, @RequestBody Event event) {
        return eventRepository.findById(id)
                .map(existing -> {
                    existing.setTitle(event.getTitle());
                    existing.setDescription(event.getDescription());
                    existing.setEventType(event.getEventType());
                    existing.setStartTime(event.getStartTime());
                    existing.setEndTime(event.getEndTime());
                    existing.setMeetLink(event.getMeetLink());
                    existing.setVenue(event.getVenue());
                    existing.setAttendanceRequired(event.getAttendanceRequired());
                    existing.setBatchId(event.getBatchId());
                    existing.setPlanId(event.getPlanId());
                    return ResponseEntity.ok(eventRepository.save(existing));
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteEvent(@PathVariable Long id) {
        eventRepository.deleteById(id);
        return ResponseEntity.ok().build();
    }
}