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
      final response = await http.get(
        Uri.parse('$baseUrl/events'),
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
}
