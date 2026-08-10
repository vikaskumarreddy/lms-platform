package com.institute.lms.controller;

import com.institute.lms.dto.user.StudentRequest;
import com.institute.lms.dto.user.StudentResponse;
import com.institute.lms.entity.User;
import com.institute.lms.repository.UserRepository;
import com.institute.lms.service.UserService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/faculty")
public class FacultyController {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final UserService userService;

    public FacultyController(UserRepository userRepository, PasswordEncoder passwordEncoder, UserService userService) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.userService = userService;
    }

    @GetMapping
    public List<StudentResponse> getAllFaculty() {
        return userRepository.findByRole(User.UserRole.INSTRUCTOR)
                .stream()
                .map(userService::toResponse)
                .collect(Collectors.toList());
    }

    @PostMapping
    public ResponseEntity<StudentResponse> createFaculty(@RequestBody StudentRequest request) {
        if (userRepository.existsByEmail(request.getEmail())) {
            return ResponseEntity.badRequest().build();
        }

        User user = new User();
        user.setName(request.getName());
        user.setEmail(request.getEmail());
        user.setPassword(passwordEncoder.encode(request.getPassword() != null && !request.getPassword().isEmpty()
                ? request.getPassword() : "faculty123"));
        user.setPhone(request.getPhone());
        user.setRole(User.UserRole.INSTRUCTOR);
        user.setIsActive(request.getIsActive() != null ? request.getIsActive() : true);
        user.setIsEmailVerified(false);

        return ResponseEntity.ok(userService.toResponse(userRepository.save(user)));
    }

    @PutMapping("/{id}")
    public ResponseEntity<StudentResponse> updateFaculty(@PathVariable Long id, @RequestBody StudentRequest request) {
        return userRepository.findById(id)
                .filter(user -> user.getRole() == User.UserRole.INSTRUCTOR)
                .map(user -> {
                    user.setName(request.getName());
                    user.setEmail(request.getEmail());
                    user.setPhone(request.getPhone());
                    if (request.getPassword() != null && !request.getPassword().isEmpty()) {
                        user.setPassword(passwordEncoder.encode(request.getPassword()));
                    }
                    if (request.getIsActive() != null) {
                        user.setIsActive(request.getIsActive());
                    }
                    return ResponseEntity.ok(userService.toResponse(userRepository.save(user)));
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteFaculty(@PathVariable Long id) {
        var userOpt = userRepository.findById(id);
        if (userOpt.isEmpty() || userOpt.get().getRole() != User.UserRole.INSTRUCTOR) {
            return ResponseEntity.notFound().build();
        }
        userRepository.delete(userOpt.get());
        return ResponseEntity.ok().build();
    }

}
