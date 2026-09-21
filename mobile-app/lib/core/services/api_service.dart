import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../../data/models/subscription_plan.dart';
import '../../data/models/course_model.dart';
import '../../data/models/course_section.dart';
import '../../data/models/lesson.dart';
import '../../data/models/event_model.dart';
import '../../data/models/assignment_model.dart';
import '../../data/models/exam_model.dart';
import '../../data/models/question_model.dart';


import '../../data/models/placement_drive_model.dart';

class ApiService {
  static const String baseUrl = AppConfig.apiBaseUrl;

  /// The logged-in student's own ID, as stored on login. Used client-side to
  /// tell "my booking" apart from other students' slots in a shared list.
  Future<int?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('userId');
  }

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<Map<String, dynamic>>> getStudyTopics() async {
    final response = await http.get(Uri.parse('$baseUrl/study-topics'),
        headers: await _getHeaders()).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('Could not load topics. Please try again.');
    }
    return (jsonDecode(response.body) as List)
        .map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<Map<String, dynamic>> createStudyTopic(String title) async {
    final response = await http.post(Uri.parse('$baseUrl/study-topics'),
        headers: await _getHeaders(), body: jsonEncode({'title': title.trim()}))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('Could not save topic. Please try again.');
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<List<Map<String, dynamic>>> getPersonalReminders() async {
    final response = await http.get(Uri.parse('$baseUrl/personal-reminders'),
        headers: await _getHeaders()).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) throw Exception('Could not load reminders');
    return (jsonDecode(response.body) as List)
        .map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<void> createPersonalReminder({required String title,
      required String description, required DateTime dueAt}) async {
    // Store the absolute instant and the selected date's UTC offset for display.
    final minutes = dueAt.timeZoneOffset.inMinutes;
    final zone = '${minutes < 0 ? '-' : '+'}${(minutes.abs() ~/ 60).toString().padLeft(2, '0')}:${(minutes.abs() % 60).toString().padLeft(2, '0')}';
    final response = await http.post(Uri.parse('$baseUrl/personal-reminders'),
        headers: await _getHeaders(), body: jsonEncode({
          'title': title.trim(), 'description': description.trim(),
          'dueAt': dueAt.toUtc().toIso8601String(), 'timeZone': zone,
        })).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) throw Exception('Could not save reminder');
  }

  Future<void> updateReminderStatus(int id, String status) async {
    final response = await http.patch(Uri.parse('$baseUrl/personal-reminders/$id/status'),
        headers: await _getHeaders(), body: jsonEncode({'status': status}))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) throw Exception('Could not update reminder');
  }

  Future<void> updatePersonalReminder(int id, {required String title,
      required String description, required DateTime dueAt}) async {
    final minutes = dueAt.timeZoneOffset.inMinutes;
    final zone = '${minutes < 0 ? '-' : '+'}${(minutes.abs() ~/ 60).toString().padLeft(2, '0')}:${(minutes.abs() % 60).toString().padLeft(2, '0')}';
    final response = await http.put(Uri.parse('$baseUrl/personal-reminders/$id'),
        headers: await _getHeaders(), body: jsonEncode({
          'title': title.trim(), 'description': description.trim(),
          'dueAt': dueAt.toUtc().toIso8601String(), 'timeZone': zone,
        })).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) throw Exception('Could not update reminder');
  }

  Future<void> deletePersonalReminder(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/personal-reminders/$id'),
        headers: await _getHeaders()).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Could not delete reminder');
    }
  }


  Future<List<SubscriptionPlanModel>> getSubscriptionPlans() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/subscription-plans'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => SubscriptionPlanModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching subscription plans: $e');
      return [];
    }
  }

  // ------------------------------------------------------------- plan upgrades
  // Students can ask to change plan but never grant it themselves; an org admin
  // approves the request, and only then does the student's plan actually move.

  /// This student's upgrade requests, newest first. Used to show pending state.
  Future<List<Map<String, dynamic>>> getMyPlanRequests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      if (userId == null) return [];

      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/student-plan-requests/student/$userId'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as List;
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching plan requests: $e');
      return [];
    }
  }

  /// Raises an upgrade request. Returns null on success, or the server's message
  /// (e.g. "You already have an upgrade request awaiting review.") on refusal.
  Future<String?> requestPlanUpgrade(int planId, {String? note}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      if (userId == null) return 'Please log in again.';

      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/student-plan-requests'),
        headers: headers,
        body: json.encode({
          'studentId': userId,
          'requestedPlanId': planId,
          if (note != null && note.isNotEmpty) 'note': note,
        }),
      );
      if (response.statusCode == 200) return null;

      try {
        final body = json.decode(response.body);
        if (body is Map && body['error'] != null) return body['error'].toString();
      } catch (_) {}
      return 'Could not send your request. Please try again.';
    } catch (e) {
      print('Error requesting plan upgrade: $e');
      return 'Could not reach the server. Check your connection.';
    }
  }

  Future<bool> updateUserPlan(int planId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');

      if (userId == null) return false;

      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/users/$userId/plan'),
        headers: headers,
        body: json.encode({'planId': planId}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating user plan: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      
      if (userId == null) return null;

      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/students/$userId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }

  /// Persists profile edits (name/email/phone/linkedin/github) to the backend.
  /// The backend PUT /api/students/{id} requires name+email (NotBlank), so we
  /// merge with the existing profile fields to avoid wiping them out.
  Future<bool> updateUserProfile({
    required String name,
    required String email,
    String? phone,
    String? linkedin,
    String? github,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      if (userId == null) return false;

      // The backend PUT /api/students/{id} sets planId/batchId directly from the
      // request body (admin portal relies on this to explicitly clear them), so we
      // must fetch and re-send the student's current planId/batchId here, otherwise
      // this self-service profile edit would silently unassign them from their
      // batch and subscription plan.
      final currentProfile = await getUserProfile();

      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/students/$userId'),
        headers: headers,
        body: json.encode({
          'name': name,
          'email': email,
          'phone': phone,
          'linkedin': linkedin,
          'github': github,
          'planId': currentProfile?['planId'],
          'batchId': currentProfile?['batchId'],
          'isActive': currentProfile?['isActive'],
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating user profile: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getStudentDashboard() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      if (userId == null) return {};

      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/dashboard/student/$userId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {};
    } catch (e) {
      print('Error fetching student dashboard: $e');
      return {};
    }
  }

  // ---------------------------------------------------------------- mentors
  // The dashboard's "Your Mentors" card. Mentors are derived server-side from the
  // student's batch mentor plus the instructors of their courses — there is no
  // separate assignment table, and this card used to be a hardcoded placeholder.

  /// Mentors of the logged-in user. Empty list when the student has no batch
  /// mentor and no course instructor yet (an honest "nothing configured" state).
  Future<List<Map<String, dynamic>>> getMyMentors() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/mentors/me'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Error fetching mentors: $e');
      return [];
    }
  }

  // ------------------------------------------------------- study time ledger
  // Records how long a student actually spends in a lesson. Consumed by the
  // dashboard's "Time Spending" trend.

  /// Opens a study session for a lesson. Returns the session id to close later,
  /// or null when the backend is unreachable (the player must keep working).
  Future<int?> startStudySession({
    required int lessonId,
    int? courseId,
    String source = 'LESSON',
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/study-time/start'),
        headers: headers,
        body: json.encode({
          'lessonId': lessonId,
          if (courseId != null) 'courseId': courseId,
          'source': source,
        }),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return (data['logId'] as num?)?.toInt();
      }
      return null;
    } catch (e) {
      print('Error starting study session: $e');
      return null;
    }
  }

  /// Closes a study session. With no [logId] the backend closes whichever session
  /// is still open for this student, which is the reliable path on dispose.
  Future<bool> endStudySession({int? logId}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse(logId == null
            ? '$baseUrl/study-time/stop-active'
            : '$baseUrl/study-time/$logId/stop'),
        headers: headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error ending study session: $e');
      return false;
    }
  }

  /// The student's study-time summary: totalMinutes, todayMinutes, monthMinutes,
  /// sessionCount and a 12-point `monthly` series of {period, label, minutes}.
  Future<Map<String, dynamic>> getStudyTimeSummary() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/study-time/summary'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {};
    } catch (e) {
      print('Error fetching study time summary: $e');
      return {};
    }
  }

  /// The next [limit] events for the logged-in student, soonest first — the
  /// dashboard "Upcoming" card's own endpoint rather than a client-side filter
  /// over the whole event feed.
  Future<List<EventModel>> getMyUpcomingEvents({int limit = 2}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      if (userId == null) return [];

      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/dashboard/student/$userId/upcoming-events?limit=$limit'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => EventModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching upcoming events: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getAttendanceHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      if (userId == null) return {'history': [], 'percentage': 0.0, 'presentCount': 0, 'totalEvents': 0};

      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/attendance/student/$userId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'history': [], 'percentage': 0.0, 'presentCount': 0, 'totalEvents': 0};
    } catch (e) {
      print('Error fetching attendance history: $e');
      return {'history': [], 'percentage': 0.0, 'presentCount': 0, 'totalEvents': 0};
    }
  }

  Future<Map<String, dynamic>> getPlacementOverview() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      if (userId == null) return {'items': [], 'totalPosted': 0, 'openCount': 0, 'appliedCount': 0, 'selectedCount': 0};

      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/student-placements/overview/$userId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'items': [], 'totalPosted': 0, 'openCount': 0, 'appliedCount': 0, 'selectedCount': 0};
    } catch (e) {
      print('Error fetching placement overview: $e');
      return {'items': [], 'totalPosted': 0, 'openCount': 0, 'appliedCount': 0, 'selectedCount': 0};
    }
  }

  Future<bool> applyToPlacementDrive(int driveId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      if (userId == null) return false;

      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/student-placements/apply'),
        headers: headers,
        body: json.encode({'userId': userId, 'driveId': driveId}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error applying to placement drive: $e');
      return false;
    }
  }

  Future<List<CourseModel>> getCourses() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/courses'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => CourseModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching courses: $e');
      return [];
    }
  }

  Future<List<EventModel>> getEvents() async {
    try {
      final headers = await _getHeaders();
      final prefs = await SharedPreferences.getInstance();
      final batchId = prefs.getInt('batchId');

      String uri;
      if (batchId != null) {
        uri = '$baseUrl/events/batch/$batchId';
      } else {
        uri = '$baseUrl/events';
      }

      final response = await http.get(
        Uri.parse(uri),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => EventModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching events: $e');
      return [];
    }
  }

  Future<List<AssignmentModel>> getAssignments() async {
    try {
      final headers = await _getHeaders();
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      if (userId == null) return [];
      
      final response = await http.get(
        Uri.parse('$baseUrl/assignments/user/$userId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> assignments = data['assignments'] ?? [];
        return assignments.map((json) => AssignmentModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching assignments: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getAssignmentsWithStats() async {
    try {
      final headers = await _getHeaders();
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      if (userId == null) return {'assignments': [], 'totalAssignments': 0, 'pendingCount': 0, 'submittedCount': 0, 'overdueCount': 0};
      
      final response = await http.get(
        Uri.parse('$baseUrl/assignments/user/$userId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'assignments': [], 'totalAssignments': 0, 'pendingCount': 0, 'submittedCount': 0, 'overdueCount': 0};
    } catch (e) {
      print('Error fetching assignments with stats: $e');
      return {'assignments': [], 'totalAssignments': 0, 'pendingCount': 0, 'submittedCount': 0, 'overdueCount': 0};
    }
  }

  Future<List<ExamModel>> getExams() async {
    try {
      final headers = await _getHeaders();
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      if (userId == null) return [];
      
      final response = await http.get(
        Uri.parse('$baseUrl/exams/user/$userId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> exams = data['exams'] ?? [];
        return exams.map((json) => ExamModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching exams: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getExamsWithStats() async {
    try {
      final headers = await _getHeaders();
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      if (userId == null) return {'exams': [], 'totalExams': 0, 'upcomingCount': 0, 'completedCount': 0, 'averageScore': 0.0};
      
      final response = await http.get(
        Uri.parse('$baseUrl/exams/user/$userId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'exams': [], 'totalExams': 0, 'upcomingCount': 0, 'completedCount': 0, 'averageScore': 0.0};
    } catch (e) {
      print('Error fetching exams with stats: $e');
      return {'exams': [], 'totalExams': 0, 'upcomingCount': 0, 'completedCount': 0, 'averageScore': 0.0};
    }
  }

  Future<List<PlacementDriveModel>> getPlacementDrives() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/placement-drives'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => PlacementDriveModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching placement drives: $e');
      return [];
    }
  }

  /// Fetches the current student's placement-eligibility metrics (percentages)
  /// used to decide whether they meet a drive's criteria.
  Future<Map<String, dynamic>> getPlacementMetrics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      if (userId == null) return {};

      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/student-stats/$userId/placement-metrics'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return {};
    } catch (e) {
      print('Error fetching placement metrics: $e');
      return {};
    }
  }

  Future<List<CourseSection>> getCourseSections(int courseId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/courses/$courseId/sections'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => CourseSection.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching course sections: $e');
      return [];
    }
  }

  Future<List<Lesson>> getModuleLessons(int moduleId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/modules/$moduleId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> lessonsJson = data['lessons'] ?? [];
        return lessonsJson.map((json) => Lesson.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching module lessons: $e');
      return [];
    }
  }

  Future<Lesson?> getLesson(int lessonId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/lessons/$lessonId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return Lesson.fromJson(data);
      }
      return null;
    } catch (e) {
      print('Error fetching lesson: $e');
      return null;
    }
  }

  Future<bool> toggleLessonComplete(int lessonId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/lessons/$lessonId/toggle-complete'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['completed'] ?? false;
      }
      return false;
    } catch (e) {
      print('Error toggling lesson complete: $e');
      return false;
    }
  }

  Future<bool> toggleLessonBookmark(int lessonId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/lessons/$lessonId/toggle-bookmark'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['bookmarked'] ?? false;
      }
      return false;
    } catch (e) {
      print('Error toggling lesson bookmark: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getLessonStatus(int lessonId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/lessons/$lessonId/status'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'completed': false, 'bookmarked': false};
    } catch (e) {
      print('Error fetching lesson status: $e');
      return {'completed': false, 'bookmarked': false};
    }
  }

  Future<List<Map<String, dynamic>>> getBookmarks() async {
    try {
      final headers = await _getHeaders();
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      if (userId == null) return [];
      
      final response = await http.get(
        Uri.parse('$baseUrl/bookmarks/user/$userId'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Error fetching bookmarks: $e');
      return [];
    }
  }

  Future<bool> toggleBookmark(int lessonId) async {
    try {
      final headers = await _getHeaders();
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      if (userId == null) return false;
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/bookmarks/toggle?userId=$userId&lessonId=$lessonId'),
        headers: headers,
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Error toggling bookmark: $e');
      return false;
    }
  }

  Future<bool> deleteBookmark(int lessonId) async {
    try {
      final headers = await _getHeaders();
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      if (userId == null) return false;
      
      final response = await http.delete(
        Uri.parse('$baseUrl/api/bookmarks/user/$userId/lesson/$lessonId'),
        headers: headers,
      );
      
      return response.statusCode == 204;
    } catch (e) {
      print('Error deleting bookmark: $e');
      return false;
    }
  }

  Future<bool> submitAssignment(int assignmentId, int userId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/assignments/$assignmentId/submit'),
        headers: headers,
        body: json.encode({'userId': userId}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error submitting assignment: $e');
      return false;
    }
  }

  Future<bool> submitExam(int examId, int userId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/exams/$examId/submit'),
        headers: headers,
        body: json.encode({'userId': userId}),
      );
            return response.statusCode == 200;
    } catch (e) {
      print('Error submitting exam: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------- in-app papers
  // [type] is 'assignments' or 'exams', matching the admin portal URLs.

  /// The paper as the student is allowed to see it: no answer key, no explanations.
  Future<Map<String, dynamic>?> getAssessmentPaper(String type, int assessmentId, int userId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/assessments/$type/$assessmentId/paper?userId=$userId'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error fetching assessment paper: $e');
      return null;
    }
  }

  /// Submits and auto-grades in one call; the response already contains the key
  /// and explanations so the review screen needs no second request.
  /// [answers] is questionId -> the option ids the student ticked.
  /// [textAnswers] is questionId -> typed text, for FILL_IN_BLANK/CODING questions.
  Future<Map<String, dynamic>?> submitAssessmentAttempt(
    String type,
    int assessmentId,
    int userId,
    Map<int, List<int>> answers, {
    Map<int, String>? textAnswers,
    int? timeTakenSeconds,
  }) async {
    try {
      final headers = await _getHeaders();
      final questionIds = <int>{...answers.keys, ...?textAnswers?.keys};
      final response = await http.post(
        Uri.parse('$baseUrl/assessments/$type/$assessmentId/attempt'),
        headers: headers,
        body: json.encode({
          'userId': userId,
          'timeTakenSeconds': timeTakenSeconds,
          'answers': questionIds
              .map((id) => {
                    'questionId': id,
                    'selectedOptionIds': answers[id] ?? const [],
                    'answerText': textAnswers?[id],
                  })
              .toList(),
        }),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      print('Attempt rejected (${response.statusCode}): ${response.body}');
      return null;
    } catch (e) {
      print('Error submitting assessment attempt: $e');
      return null;
    }
  }

  /// A previous attempt with the key and explanations, for re-opening the review.
  Future<Map<String, dynamic>?> getAssessmentReview(String type, int assessmentId, int userId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/assessments/$type/$assessmentId/review?userId=$userId'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error fetching assessment review: $e');
      return null;
    }
  }

  /// Read-only Q&A guide for a "Company Questions" tile. Company kits are an
  /// interview-prep guide (not a graded paper), so every question is returned
  /// together with its reference answer, correct options and explanation. The
  /// server rejects this for anything other than a company kit.
  Future<Map<String, dynamic>?> getCompanyKitGuide(int assessmentId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/assessments/company-kit/$assessmentId/guide'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error fetching company kit guide: $e');
      return null;
    }
  }

  Future<List<QuestionModel>> getQuestions() async {
    try {
      final headers = await _getHeaders();
      final prefs = await SharedPreferences.getInstance();
      final batchId = prefs.getInt('batchId');

      String uri;
      if (batchId != null) {
        uri = '$baseUrl/questions/batch/$batchId';
      } else {
        uri = '$baseUrl/questions';
      }

      final response = await http.get(
        Uri.parse(uri),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => QuestionModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching questions: $e');
      return [];
    }
  }

  Future<List<AnswerModel>> getAnswersByQuestion(int questionId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/questions/$questionId/answers'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => AnswerModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching answers: $e');
      return [];
    }
  }

  Future<QuestionModel?> createQuestion({
    required String title,
    required String content,
    required String category,
    String? authorName,
    int? planId,
    int? batchId,
    int? userId,
  }) async {
    try {
      final headers = await _getHeaders();
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getInt('userId');
      final currentBatchId = prefs.getInt('batchId');

      final response = await http.post(
        Uri.parse('$baseUrl/questions'),
        headers: headers,
        body: json.encode({
          'title': title,
          'content': content,
          'category': category,
          'authorName': authorName,
          'planId': planId,
          'batchId': batchId ?? currentBatchId,
          'userId': userId ?? currentUserId,
        }),
      );

      if (response.statusCode == 200) {
        return QuestionModel.fromJson(json.decode(response.body));
      }
      return null;
    } catch (e) {
      print('Error creating question: $e');
      return null;
    }
  }

  Future<AnswerModel?> createAnswer(int questionId, String content, {String? authorName}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/questions/$questionId/answers'),
        headers: headers,
        body: json.encode({
          'content': content,
          'authorName': authorName,
        }),
      );

      if (response.statusCode == 200) {
        return AnswerModel.fromJson(json.decode(response.body));
      }
      return null;
    } catch (e) {
      print('Error creating answer: $e');
      return null;
    }
  }

  /// Returns the plan ids the logged-in student currently has ACTIVE access to,
  /// across *all* of their subscriptions (a student may be subscribed to more
  /// than one plan at once, e.g. "Java Full Stack" + "Placement Pro").
  Future<List<int>> getActivePlanIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      if (userId == null) return [];

      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/students/$userId/subscriptions/active-plan-ids'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((e) => (e as num).toInt()).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching active plan ids: $e');
      return [];
    }
  }

  /// Registers/refreshes this device's FCM token with the backend so push
  /// notifications (admin broadcasts, deadline reminders, class reminders,
  /// interview confirmations, etc.) can actually reach it.
  Future<bool> updateFcmToken(String fcmToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      if (userId == null) return false;

      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/students/$userId/fcm-token'),
        headers: headers,
        body: json.encode({'fcmToken': fcmToken}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating FCM token: $e');
      return false;
    }
  }

  // MARK: - Interview Slots (internal placement drives)

  Future<List<Map<String, dynamic>>> getInterviewSlotsForDrive(int driveId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/interview-slots/drive/$driveId'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Error fetching interview slots: $e');
      return [];
    }
  }

  Future<bool> bookInterviewSlot(int slotId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      if (userId == null) return false;

      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/interview-slots/$slotId/book'),
        headers: headers,
        body: json.encode({'userId': userId}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error booking interview slot: $e');
      return false;
    }
  }

  Future<bool> cancelInterviewSlot(int slotId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/interview-slots/$slotId/cancel'),
        headers: headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error cancelling interview slot: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getMyInterviewHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      if (userId == null) return [];

      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/interview-slots/student/$userId'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Error fetching interview history: $e');
      return [];
    }
  }

  // MARK: - Payment History APIs

  Future<List<Map<String, dynamic>>> getPaymentHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      if (userId == null) return [];

      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/payments/history/$userId'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Error fetching payment history: $e');
      return [];
    }
  }

  // MARK: - Online Payment APIs

  /// The logged-in student's payment status: {paymentRequired, paymentMethod,
  /// paymentStatus, gateway, amountDue (rupees), paidAt}.
  Future<Map<String, dynamic>?> getPaymentStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      if (userId == null) return null;
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/payments/status/$userId'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error fetching payment status: $e');
      return null;
    }
  }

  /// Creates a gateway order for the student's pending enrollment fee.
  /// Returns the gateway-specific order payload (orderId, amount, currency,
  /// keyId for Razorpay; actionUrl + form fields for PayU; paymentSessionId
  /// for Cashfree).
  Future<Map<String, dynamic>?> createPaymentOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      if (userId == null) return null;
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/payments/create-order/$userId'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      final body = response.body.isNotEmpty ? json.decode(response.body) : {};
      throw Exception(body['error'] ?? 'Could not create payment order (HTTP ${response.statusCode})');
    } catch (e) {
      print('Error creating payment order: $e');
      rethrow;
    }
  }

  /// Live status of a gateway order: {paid: bool}. Polled by the payment screen
  /// while the vendor's checkout page is open in the webview.
  Future<bool> isOrderPaid(String orderId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/payments/order-status/$orderId'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return json.decode(response.body)['paid'] == true;
      }
      return false;
    } catch (e) {
      print('Error checking order status: $e');
      return false;
    }
  }

  // MARK: - Leaderboard

  Future<Map<String, dynamic>> getWeeklyLeaderboard({int? batchId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      final effectiveBatchId = batchId ?? prefs.getInt('batchId');

      final headers = await _getHeaders();
      final params = <String, String>{};
      if (effectiveBatchId != null) params['batchId'] = effectiveBatchId.toString();
      if (userId != null) params['studentId'] = userId.toString();
      final uri = Uri.parse('$baseUrl/leaderboard').replace(queryParameters: params.isEmpty ? null : params);

      final response = await http.get(uri, headers: headers);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'entries': [], 'myRank': null};
    } catch (e) {
      print('Error fetching leaderboard: $e');
      return {'entries': [], 'myRank': null};
    }
  }

  // MARK: - Certificates API

  Future<List<Map<String, dynamic>>> getCertificates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      if (userId == null) return [];

      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/certificates/user/$userId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Error fetching certificates: $e');
      return [];
    }
  }

  // MARK: - Notes APIs

  Future<List<Map<String, dynamic>>> getNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      if (userId == null) return [];

      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/notes/user/$userId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Error fetching notes: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> createNote({required String title, required String content, int? lessonId, int? topicId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      if (userId == null) return null;

      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/notes'),
        headers: headers,
        body: json.encode({
          'userId': userId,
          'lessonId': lessonId,
          'topicId': topicId,
          'title': title,
          'content': content,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error creating note: $e');
      return null;
    }
  }

  Future<bool> updateNote(int noteId, {String? title, String? content, int? topicId}) async {
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{};
      if (title != null) body['title'] = title;
      if (content != null) body['content'] = content;
      if (topicId != null) body['topicId'] = topicId;

      final response = await http.put(
        Uri.parse('$baseUrl/notes/$noteId'),
        headers: headers,
        body: json.encode(body),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating note: $e');
      return false;
    }
  }

  Future<bool> deleteNote(int noteId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/notes/$noteId'),
        headers: headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting note: $e');
      return false;
    }
  }

  // MARK: - Mentor Grading APIs

  Future<List<Map<String, dynamic>>> getAssignmentSubmissionsForMentor(int batchId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/assignment-submissions'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Error fetching assignment submissions: $e');
      return [];
    }
  }

  Future<bool> gradeAssignmentSubmission(int submissionId, {int? marksObtained, String? feedback}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/assignment-submissions/$submissionId'),
        headers: headers,
        body: json.encode({
          'marksObtained': marksObtained,
          'feedback': feedback,
          'isGraded': marksObtained != null,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error grading assignment submission: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getExamSubmissionsForMentor(int batchId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/exam-submissions'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Error fetching exam submissions: $e');
      return [];
    }
  }

  Future<bool> gradeExamSubmission(int submissionId, {int? marksObtained, String? remarks}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/exam-submissions/$submissionId'),
        headers: headers,
        body: json.encode({
          'marksObtained': marksObtained,
          'remarks': remarks,
          'isGraded': marksObtained != null,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error grading exam submission: $e');
      return false;
    }
  }

  // MARK: - Company Question Kit APIs

  /// Published tiles only; [studentId] flags each with the student's favorite state.
  Future<List<Map<String, dynamic>>> getCompanyKits(int studentId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/company-kits/published?studentId=$studentId'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Error fetching company kits: $e');
      return [];
    }
  }

  Future<List<int>> getCompanyKitFavorites(int studentId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/company-kits/favorites/$studentId'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.whereType<num>().map((n) => n.toInt()).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching company kit favorites: $e');
      return [];
    }
  }

  /// Toggles - adds if absent, removes if present. Returns the new favorite state.
  Future<bool?> toggleCompanyKitFavorite({required int studentId, required int kitId}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/company-kits/favorites/toggle'),
        headers: headers,
        body: json.encode({'studentId': studentId, 'kitId': kitId}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return data['isFavorite'] == true;
      }
      return null;
    } catch (e) {
      print('Error toggling company kit favorite: $e');
      return null;
    }
  }

  // MARK: - Feedback APIs

  Future<List<Map<String, dynamic>>> getMyFeedback() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/feedback/me'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Error fetching feedback: $e');
      return [];
    }
  }

  Future<bool> submitFeedback({required String type, required int rating, required String comment}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/feedback'),
        headers: headers,
        body: json.encode({
          'type': type,
          'rating': rating,
          'comment': comment,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error submitting feedback: $e');
      return false;
    }
  }

  // MARK: - Support Request APIs
  // A student asking placements staff about a drive (or an off-list company
  // via "Other"). No approve/reject cycle — an admin replies once and the
  // student sees the reply here.

  Future<List<Map<String, dynamic>>> getMySupportRequests() async {
    try {
      final userId = await getCurrentUserId();
      if (userId == null) return [];

      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/support-requests/student/$userId'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as List;
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching support requests: $e');
      return [];
    }
  }

  /// Raises a support request, either against a real [driveId] or a free-text
  /// [companyName] when the student picked "Other". Returns null on success,
  /// or the server's error message on refusal.
  Future<String?> submitSupportRequest({int? driveId, String? companyName, required String message}) async {
    try {
      final userId = await getCurrentUserId();
      if (userId == null) return 'Please log in again.';

      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/support-requests'),
        headers: headers,
        body: json.encode({
          'studentId': userId,
          if (driveId != null) 'driveId': driveId,
          if (companyName != null && companyName.isNotEmpty) 'companyName': companyName,
          'message': message,
        }),
      );
      if (response.statusCode == 200) return null;

      try {
        final body = json.decode(response.body);
        if (body is Map && body['error'] != null) return body['error'].toString();
      } catch (_) {}
      return 'Could not send your request. Please try again.';
    } catch (e) {
      print('Error submitting support request: $e');
      return 'Could not reach the server. Check your connection.';
    }
  }

  // MARK: - Comment APIs

  Future<List<Map<String, dynamic>>> getCommentsForLesson(int lessonId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/comments/lesson/$lessonId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Error fetching comments: $e');
      return [];
    }
  }

  Future<bool> postComment({required int lessonId, required String content, int? parentId}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/comments'),
        headers: headers,
        body: json.encode({
          'lessonId': lessonId,
          'content': content,
          if (parentId != null) 'parentId': parentId,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error posting comment: $e');
      return false;
    }
  }

  // MARK: - Organization theme
  //
  // Mirrors the admin-portal's brand-color customization (Settings > Theme):
  // the same `theme` map returned in `GET /api/organizations/current` there is
  // read here so the student app matches whatever colors the tenant picked.

  /// The current organization's `theme` map (CSS-variable-style keys -> hex colors),
  /// merged with platform defaults server-side, or null if the call fails.
  Future<Map<String, dynamic>?> getOrganizationTheme() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/organizations/current'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        final theme = decoded['theme'];
        return theme is Map<String, dynamic> ? theme : null;
      }
      return null;
    } catch (e) {
      print('Error fetching organization theme: $e');
      return null;
    }
  }

  /// The current organization's display name (e.g. "Axisora Technologies"),
  /// shown centered in the shared glass header. Null when unavailable.
  Future<String?> getCurrentOrganizationName() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/organizations/current'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        return (decoded['name'] as String?)?.trim();
      }
      return null;
    } catch (e) {
      print('Error fetching organization name: $e');
      return null;
    }
  }
}
