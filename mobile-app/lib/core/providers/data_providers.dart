import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms_student_app/core/services/api_service.dart';
import 'package:lms_student_app/data/models/course_model.dart';
import 'package:lms_student_app/data/models/course_section.dart';
import 'package:lms_student_app/data/models/lesson.dart';
import 'package:lms_student_app/data/models/assignment_model.dart';
import 'package:lms_student_app/data/models/exam_model.dart';
import 'package:lms_student_app/data/models/event_model.dart';
import 'package:lms_student_app/data/models/mentor_model.dart';
import 'package:lms_student_app/data/models/placement_drive_model.dart';
import 'package:lms_student_app/data/models/bookmark_model.dart';
import 'notifications_provider.dart';

export 'org_theme_provider.dart';
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());


/// The logged-in student's mentors (batch mentor + course instructors).
final mentorsProvider = FutureProvider<List<MentorModel>>((ref) async {
  final json = await ref.watch(apiServiceProvider).getMyMentors();
  return json.map((item) => MentorModel.fromJson(item)).toList();
});

/// The student's study-time summary — totals plus a 12-point monthly series of
/// {period, label, minutes} recorded from real lesson sessions.
final studyTimeSummaryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.watch(apiServiceProvider).getStudyTimeSummary();
});

/// The next two events for the logged-in student, from the dashboard endpoint.
final myUpcomingEventsProvider = FutureProvider<List<EventModel>>((ref) async {
  return ref.watch(apiServiceProvider).getMyUpcomingEvents(limit: 2);
});

final coursesProvider = FutureProvider<List<CourseModel>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getCourses();
});

final courseSectionsProvider = FutureProvider.family<List<CourseSection>, int>((ref, courseId) async {
  final api = ref.watch(apiServiceProvider);
  return api.getCourseSections(courseId);
});

final moduleLessonsProvider = FutureProvider.family<List<Lesson>, int>((ref, moduleId) async {
  final api = ref.watch(apiServiceProvider);
  return api.getModuleLessons(moduleId);
});

final lessonProvider = FutureProvider.family<Lesson?, int>((ref, lessonId) async {
  final api = ref.watch(apiServiceProvider);
  return api.getLesson(lessonId);
});

final assignmentsProvider = FutureProvider<List<AssignmentModel>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getAssignments();
});

final examsProvider = FutureProvider<List<ExamModel>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getExams();
});

final placementDrivesProvider = FutureProvider<List<PlacementDriveModel>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getPlacementDrives();
});

/// Current student's placement-eligibility metrics (percentages) keyed by
/// metric name, e.g. {'attendancePercentage': 86.5}. Empty map when unavailable.
final placementMetricsProvider = FutureProvider<Map<String, double>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final json = await api.getPlacementMetrics();
  return <String, double>{
    'attendancePercentage': (json['attendancePercentage'] as num?)?.toDouble() ?? -1,
    'courseCompletionPercentage': (json['courseCompletionPercentage'] as num?)?.toDouble() ?? -1,
    'assignmentAveragePercentage': (json['assignmentAveragePercentage'] as num?)?.toDouble() ?? -1,
    'examAveragePercentage': (json['examAveragePercentage'] as num?)?.toDouble() ?? -1,
  };
});

final userProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getUserProfile();
});

final bookmarksProvider = FutureProvider<List<BookmarkModel>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final bookmarksJson = await api.getBookmarks();
  return bookmarksJson.map((json) => BookmarkModel.fromJson(json)).toList();
});

final placementOverviewProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getPlacementOverview();
});

final attendanceHistoryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getAttendanceHistory();
});

final certificatesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getCertificates();
});

final studentDashboardProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getStudentDashboard();
});

final interviewHistoryProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getMyInterviewHistory();
});

/// Global state indicating whether the student has hidden the main bottom navigation bar
/// to use the platform in distraction-free mode.
final shellNavBarHiddenProvider = StateProvider<bool>((ref) => false);

/// Clears all in-memory student cached data in Riverpod providers so that
/// logging out and logging in as another student immediately fetches that student's
/// fresh data without needing to terminate or restart the application.
void invalidateAllUserData(dynamic ref) {
  ref.invalidate(shellNavBarHiddenProvider);
  ref.invalidate(userProfileProvider);
  ref.invalidate(coursesProvider);
  ref.invalidate(mentorsProvider);
  ref.invalidate(studyTimeSummaryProvider);
  ref.invalidate(myUpcomingEventsProvider);
  ref.invalidate(assignmentsProvider);
  ref.invalidate(examsProvider);
  ref.invalidate(placementDrivesProvider);
  ref.invalidate(placementMetricsProvider);
  ref.invalidate(placementOverviewProvider);
  ref.invalidate(attendanceHistoryProvider);
  ref.invalidate(certificatesProvider);
  ref.invalidate(bookmarksProvider);
  ref.invalidate(studentDashboardProvider);
  ref.invalidate(interviewHistoryProvider);
  ref.invalidate(notificationsProvider);
  ref.invalidate(unreadCountProvider);
}
