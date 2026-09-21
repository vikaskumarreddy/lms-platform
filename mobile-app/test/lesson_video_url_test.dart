import 'package:flutter_test/flutter_test.dart';
import 'package:lms_student_app/core/config/app_config.dart';
import 'package:lms_student_app/core/utils/lesson_media.dart';
import 'package:lms_student_app/data/models/lesson.dart';

/// Targeted tests for the exact video URL the lesson player loads, using
/// backend-shaped lesson JSON through the real [Lesson] model and the real
/// [LessonPlayerScreen] widget.
void main() {
  final origin = Uri.parse(AppConfig.apiBaseUrl).origin;

  Lesson backendLesson(Map<String, dynamic> overrides) => Lesson.fromJson({
        'id': 7,
        'title': 'Intro to Dart',
        'heading': 'Intro to Dart',
        'durationMinutes': 12,
        'isLocked': false,
        'pdfNotesUrl': '',
        'notes': 'hello',
        ...overrides,
      });

  test('SELF lesson loads its /api/media URL with the session token', () {
    final lesson = backendLesson(
        {'videoSource': 'SELF', 'videoUrl': '/api/media/42/serve'});
    final video = resolveLessonVideoSource(lesson, AppConfig.apiBaseUrl,
        token: 'test-session');
    expect(video.youtube, isFalse);
    expect(video.url, '$origin/api/media/42/serve?token=test-session');
    final doc = videoDocument(video.url);
    expect(doc, contains('<video'));
    expect(doc, isNot(contains('<iframe')));
    expect(doc, contains('src="${video.url}"'));
  });

  test('YouTube lesson embeds its own id, never a placeholder', () {
    final lesson = backendLesson({
      'videoSource': 'URL',
      'videoUrl': 'https://youtu.be/abcdefghijk?si=x'
    });
    final video = resolveLessonVideoSource(lesson, AppConfig.apiBaseUrl,
        token: 'test-session');
    expect(video.youtube, isTrue);
    expect(
        video.url,
        'https://www.youtube.com/embed/abcdefghijk'
        '?playsinline=1&rel=0&origin=${Uri.encodeComponent(origin)}');
    expect(videoDocument(video.url, youtube: true), contains('<iframe'));
    // A random absolute URL must never be misread as a YouTube video id.
    expect(
        resolveLessonVideoSource(
                backendLesson({
                  'videoSource': 'URL',
                  'videoUrl': 'https://cdn.example/abcdefghijk'
                }),
                AppConfig.apiBaseUrl)
            .youtube,
        isFalse);
  });

  test('External absolute video URLs load verbatim with no credentials', () {
    final lesson = backendLesson(
        {'videoSource': 'URL', 'videoUrl': 'https://cdn.example/lesson.mp4'});
    expect(
        resolveLessonVideoSource(lesson, AppConfig.apiBaseUrl,
                token: 'test-session')
            .url,
        'https://cdn.example/lesson.mp4');
  });
}
