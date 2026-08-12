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

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
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

  Future<Map<String, dynamic>?> createNote({required String title, required String content, int? lessonId}) async {
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

  Future<bool> updateNote(int noteId, {String? title, String? content}) async {
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{};
      if (title != null) body['title'] = title;
      if (content != null) body['content'] = content;

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
}
