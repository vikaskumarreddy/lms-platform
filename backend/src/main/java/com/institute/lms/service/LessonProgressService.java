package com.institute.lms.service;

import com.institute.lms.entity.Bookmark;
import com.institute.lms.entity.Lesson;
import com.institute.lms.entity.Progress;
import com.institute.lms.entity.User;
import com.institute.lms.repository.BookmarkRepository;
import com.institute.lms.repository.LessonRepository;
import com.institute.lms.repository.ProgressRepository;
import com.institute.lms.repository.UserRepository;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.Optional;

@Service
public class LessonProgressService {

    private final LessonRepository lessonRepository;
    private final ProgressRepository progressRepository;
    private final BookmarkRepository bookmarkRepository;
    private final UserRepository userRepository;

    public LessonProgressService(LessonRepository lessonRepository,
                                  ProgressRepository progressRepository,
                                  BookmarkRepository bookmarkRepository,
                                  UserRepository userRepository) {
        this.lessonRepository = lessonRepository;
        this.progressRepository = progressRepository;
        this.bookmarkRepository = bookmarkRepository;
        this.userRepository = userRepository;
    }

    private User getCurrentUser() {
        try {
            Authentication auth = SecurityContextHolder.getContext().getAuthentication();
            if (auth == null || !auth.isAuthenticated()) return null;
            return userRepository.findByEmail(auth.getName()).orElse(null);
        } catch (Exception e) {
            return null;
        }
    }

    @Transactional
    public boolean toggleComplete(Long lessonId) {
        User user = getCurrentUser();
        if (user == null) return false;

        Lesson lesson = lessonRepository.findById(lessonId).orElse(null);
        if (lesson == null) return false;

        Optional<Progress> existing = progressRepository
                .findByUserIdAndLessonId(user.getId(), lessonId);

        if (existing.isPresent()) {
            progressRepository.delete(existing.get());
            return false; // now incomplete
        } else {
            Progress progress = new Progress();
            progress.setUser(user);
            progress.setLesson(lesson);
            progress.setIsCompleted(true);
            progress.setCompletedAt(LocalDateTime.now());
            progressRepository.save(progress);
            return true; // now complete
        }
    }

    @Transactional
    public boolean toggleBookmark(Long lessonId) {
        User user = getCurrentUser();
        if (user == null) return false;

        Lesson lesson = lessonRepository.findById(lessonId).orElse(null);
        if (lesson == null) return false;

        Optional<Bookmark> existing = bookmarkRepository
                .findByUserIdAndLessonId(user.getId(), lessonId);

        if (existing.isPresent()) {
            bookmarkRepository.delete(existing.get());
            return false; // now not bookmarked
        } else {
            Bookmark bookmark = new Bookmark();
            bookmark.setUser(user);
            bookmark.setLesson(lesson);
            bookmark.setBookmarkedAt(LocalDateTime.now());
            bookmarkRepository.save(bookmark);
            return true; // now bookmarked
        }
    }

    public boolean isLessonCompleted(Long lessonId) {
        User user = getCurrentUser();
        if (user == null) return false;
        return progressRepository.existsByUserIdAndLessonId(user.getId(), lessonId);
    }

    public boolean isLessonBookmarked(Long lessonId) {
        User user = getCurrentUser();
        if (user == null) return false;
        return bookmarkRepository.existsByUserIdAndLessonId(user.getId(), lessonId);
    }
}