package com.institute.lms.controller;

import com.institute.lms.entity.Event;
import com.institute.lms.repository.EventRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/events")
public class EventController {

    private final EventRepository eventRepository;

    public EventController(EventRepository eventRepository) {
        this.eventRepository = eventRepository;
    }

    @GetMapping
    public List<Event> getAllEvents() {
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
        return eventRepository.findByBatchId(batchId);
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