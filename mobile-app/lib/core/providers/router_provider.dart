import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/routes.dart';
import '../../presentation/screens/splash/splash_screen.dart';
import '../../presentation/screens/landing/landing_screen.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/register_screen.dart';
import '../../presentation/screens/auth/forgot_password_screen.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/courses/courses_screen.dart';
import '../../presentation/screens/courses/course_detail_screen.dart';
import '../../presentation/screens/courses/course_section_lessons_screen.dart';
import '../../presentation/screens/video/video_player_screen.dart';
import '../../presentation/screens/profile/profile_screen.dart';
import '../../presentation/screens/notifications/notifications_screen.dart';
import '../../presentation/screens/settings/settings_screen.dart';
import '../../presentation/screens/placement/placement_drives_screen.dart';
import '../../presentation/screens/calendar/calendar_screen.dart';
import '../../presentation/screens/assignments/assignments_screen.dart';
import '../../presentation/screens/exams/exams_screen.dart';
import '../../presentation/screens/certificates/certificates_screen.dart';
import '../../presentation/screens/resume/resume_builder_screen.dart';
import '../../presentation/screens/discussion/discussion_screen.dart';
import '../../presentation/screens/search/search_screen.dart';
import '../../presentation/screens/subscription/subscription_screen.dart';
import '../../presentation/screens/payment/payment_screen.dart';
import '../../presentation/screens/payment/payment_history_screen.dart';
import '../../presentation/screens/attendance/attendance_screen.dart';
import '../../presentation/screens/feedback/feedback_screen.dart';
import '../../presentation/screens/interviews/interview_history_screen.dart';
import '../../presentation/screens/chat/chat_screen.dart';
import '../../presentation/screens/notes/notes_screen.dart';
import '../../presentation/screens/onboarding/onboarding_screen.dart';
import '../../presentation/screens/bookmarks/bookmarks_screen.dart';
import '../../presentation/screens/leaderboard/leaderboard_screen.dart';
import '../../presentation/screens/qa/qa_screen.dart';
import '../../presentation/screens/browser/in_app_browser_screen.dart';
import '../../presentation/screens/assessment/assessment_paper_screen.dart';
import '../../presentation/screens/main_shell_screen.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (context, state) => const SplashScreen()),
      GoRoute(path: AppRoutes.landing, builder: (context, state) => const LandingScreen()),
      GoRoute(path: AppRoutes.login, builder: (context, state) => const LoginScreen()),
      GoRoute(path: AppRoutes.register, builder: (context, state) => const RegisterScreen()),
      GoRoute(path: AppRoutes.forgotPassword, builder: (context, state) => const ForgotPasswordScreen()),
      GoRoute(path: AppRoutes.onboarding, builder: (context, state) => const OnboardingScreen()),
      ShellRoute(
        builder: (context, state, child) => MainShellScreen(child: child),
        routes: [
          GoRoute(path: AppRoutes.home, builder: (context, state) => const HomeScreen()),
          GoRoute(path: AppRoutes.courses, builder: (context, state) => const CoursesScreen()),
          GoRoute(path: AppRoutes.courseDetail, builder: (context, state) => CourseDetailScreen(id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0)),
          GoRoute(path: AppRoutes.profile, builder: (context, state) => const ProfileScreen()),
          GoRoute(path: AppRoutes.notifications, builder: (context, state) => const NotificationsScreen()),
          GoRoute(path: AppRoutes.settings, builder: (context, state) => const SettingsScreen()),
          GoRoute(path: AppRoutes.placementDrives, builder: (context, state) => const PlacementDrivesScreen()),
          GoRoute(path: AppRoutes.calendar, builder: (context, state) => const CalendarScreen()),
          GoRoute(path: AppRoutes.assignments, builder: (context, state) => const AssignmentsScreen()),
          GoRoute(path: AppRoutes.exams, builder: (context, state) => const ExamsScreen()),
          GoRoute(path: AppRoutes.certificates, builder: (context, state) => const CertificatesScreen()),
          GoRoute(path: AppRoutes.resumeBuilder, builder: (context, state) => const ResumeBuilderScreen()),
          GoRoute(path: AppRoutes.discussion, builder: (context, state) => DiscussionScreen(lessonId: int.tryParse(state.pathParameters['lessonId'] ?? '') ?? 0)),
          GoRoute(path: AppRoutes.search, builder: (context, state) => const SearchScreen()),
          GoRoute(path: AppRoutes.subscription, builder: (context, state) => const SubscriptionScreen()),
          GoRoute(path: AppRoutes.paymentHistory, builder: (context, state) => const PaymentHistoryScreen()),
          GoRoute(path: AppRoutes.attendance, builder: (context, state) => const AttendanceScreen()),
          GoRoute(path: AppRoutes.feedback, builder: (context, state) => const FeedbackScreen()),
          GoRoute(path: AppRoutes.interviewHistory, builder: (context, state) => const InterviewHistoryScreen()),
          GoRoute(path: AppRoutes.bookmarks, builder: (context, state) => const BookmarksScreen()),
          GoRoute(path: AppRoutes.leaderboard, builder: (context, state) => const LeaderboardScreen()),
          GoRoute(path: AppRoutes.qa, builder: (context, state) => const QaScreen()),
        ],
      ),
      GoRoute(path: AppRoutes.inAppBrowser, builder: (context, state) => InAppBrowserScreen(
        url: state.uri.queryParameters['url'] ?? '',
        title: state.uri.queryParameters['title'] ?? 'Browser',
      )),
      // Outside the shell: a paper in progress should not show the bottom nav.
      GoRoute(
        path: AppRoutes.assessmentPaper,
        builder: (context, state) => AssessmentPaperScreen(
          type: state.pathParameters['type'] ?? 'assignments',
          assessmentId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
          title: state.uri.queryParameters['title'] ?? 'Question Paper',
          durationMinutes: int.tryParse(state.uri.queryParameters['duration'] ?? ''),
          totalMarks: int.tryParse(state.uri.queryParameters['marks'] ?? ''),
        ),
      ),
      GoRoute(path: AppRoutes.mentorChat, builder: (context, state) => ChatScreen(mentorId: int.tryParse(state.pathParameters['mentorId'] ?? '') ?? 0)),
      GoRoute(path: AppRoutes.notes, builder: (context, state) => NotesScreen(lessonId: int.tryParse(state.pathParameters['lessonId'] ?? '') ?? 0)),
      GoRoute(path: AppRoutes.payment, builder: (context, state) => PaymentScreen(planId: int.tryParse(state.pathParameters['planId'] ?? '') ?? 0)),
      GoRoute(path: AppRoutes.sectionLessons, builder: (context, state) => CourseSectionLessonsScreen(sectionId: int.tryParse(state.pathParameters['sectionId'] ?? '') ?? 0)),
      GoRoute(path: AppRoutes.lesson, builder: (context, state) => LessonPlayerScreen(lessonId: int.tryParse(state.pathParameters['lessonId'] ?? '') ?? 0)),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Page not found', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(state.error?.toString() ?? 'Unknown error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.splash),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});