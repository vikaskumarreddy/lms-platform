import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms_student_app/core/services/api_service.dart';
import 'package:lms_student_app/data/models/course_model.dart';
import 'package:lms_student_app/data/models/course_section.dart';
import 'package:lms_student_app/data/models/lesson.dart';
import 'package:lms_student_app/data/models/assignment_model.dart';
import 'package:lms_student_app/data/models/exam_model.dart';
import 'package:lms_student_app/data/models/placement_drive_model.dart';
import 'package:lms_student_app/data/models/bookmark_model.dart';

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

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
