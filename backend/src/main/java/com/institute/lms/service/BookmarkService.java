package com.institute.lms.service;

import com.institute.lms.dto.bookmark.BookmarkResponseDTO;
import com.institute.lms.entity.Bookmark;
import com.institute.lms.entity.Lesson;
import com.institute.lms.entity.User;
import com.institute.lms.repository.BookmarkRepository;
import com.institute.lms.repository.LessonRepository;
import com.institute.lms.repository.UserRepository;
import jakarta.persistence.EntityNotFoundException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

@Service
@RequiredArgsConstructor
@Slf4j
public class BookmarkService {

    private final BookmarkRepository bookmarkRepository;
    private final UserRepository userRepository;
    private final LessonRepository lessonRepository;

    public List<BookmarkResponseDTO> getUserBookmarks(Long userId) {
        return bookmarkRepository.findByUserId(userId).stream()
                .map(this::convertToDTO)
                .toList();
    }

    /** All bookmarks in the current org (tenant-scoped via {@code findAll()}) — for the admin list view. */
    public List<BookmarkResponseDTO> getAllBookmarks() {
        return bookmarkRepository.findAll().stream()
                .map(this::convertToDTO)
                .toList();
    }

    public boolean isBookmarked(Long userId, Long lessonId) {
        return bookmarkRepository.existsByUserIdAndLessonId(userId, lessonId);
    }

    @Transactional
    public void toggleBookmark(Long userId, Long lessonId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new EntityNotFoundException("User not found"));

        Lesson lesson = lessonRepository.findById(lessonId)
                .orElseThrow(() -> new EntityNotFoundException("Lesson not found"));

        Optional<Bookmark> existingBookmark = bookmarkRepository.findByUserIdAndLessonId(userId, lessonId);

        if (existingBookmark.isPresent()) {
            bookmarkRepository.delete(existingBookmark.get());
        } else {
            Bookmark bookmark = new Bookmark();
            bookmark.setUser(user);
            bookmark.setLesson(lesson);
            bookmarkRepository.save(bookmark);
        }
    }

    @Transactional
    public void deleteBookmark(Long userId, Long lessonId) {
        bookmarkRepository.findByUserIdAndLessonId(userId, lessonId)
                .ifPresent(bookmarkRepository::delete);
    }

    private BookmarkResponseDTO convertToDTO(Bookmark bookmark) {
        BookmarkResponseDTO dto = new BookmarkResponseDTO();
        dto.setId(bookmark.getId());
        if (bookmark.getUser() != null) {
            dto.setUserId(bookmark.getUser().getId());
            dto.setStudentName(bookmark.getUser().getName());
            dto.setStudentEmail(bookmark.getUser().getEmail());
        }
        dto.setLessonId(bookmark.getLesson().getId());
        dto.setLessonTitle(bookmark.getLesson().getTitle());
        dto.setBookmarkedAt(bookmark.getBookmarkedAt());
        
        if (bookmark.getLesson().getModule() != null) {
            if (bookmark.getLesson().getModule().getCourse() != null) {
                dto.setCourseName(bookmark.getLesson().getModule().getCourse().getTitle());
            }
            dto.setLessonType("Module Lesson");
        } else {
            dto.setLessonType("Lesson");
        }
        
        return dto;
    }
}