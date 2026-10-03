import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/routes.dart';
import 'auth_provider.dart';
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
import '../../presentation/screens/interviews/interview_room_screen.dart';
import '../../presentation/screens/chat/chat_screen.dart';
import '../../presentation/screens/notes/notes_screen.dart';
import '../../presentation/screens/onboarding/onboarding_screen.dart';
import '../../presentation/screens/bookmarks/bookmarks_screen.dart';
import '../../presentation/screens/leaderboard/leaderboard_screen.dart';
import '../../presentation/screens/ai_challenge/daily_challenge_screen.dart';
import '../../presentation/screens/qa/qa_screen.dart';
import '../../presentation/screens/company_questions/company_questions_screen.dart';
import '../../presentation/screens/placement/support_request_screen.dart';
import '../../presentation/screens/browser/in_app_browser_screen.dart';
import '../../presentation/screens/assessment/assessment_paper_screen.dart';
import '../../presentation/screens/main_shell_screen.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

String _placementFilter(String? value) {
  switch ((value ?? '').toLowerCase()) {
    case 'open': return 'Open';
    case 'applied': return 'Applied';
    case 'selected': return 'Selected';
    case 'rejected': return 'Rejected';
    default: return 'All';
  }
}

CustomTransitionPage<void> buildPremiumTransitionPage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final secondaryCurved = CurvedAnimation(
        parent: secondaryAnimation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      return FadeTransition(
        opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.04, 0.0),
            end: Offset.zero,
          ).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.985, end: 1.0).animate(curved),
            child: FadeTransition(
              opacity: Tween<double>(begin: 1.0, end: 0.0).animate(secondaryCurved),
              child: child,
            ),
          ),
        ),
      );
    },
  );
}

GoRoute _animatedRoute({
  required String path,
  required Widget Function(BuildContext, GoRouterState) builder,
}) {
  return GoRoute(
    path: path,
    pageBuilder: (context, state) => buildPremiumTransitionPage(
      state: state,
      child: builder(context, state),
    ),
  );
}

/// Root navigator key, shared with [InAppNotificationOverlay] so it can find
/// a live [OverlayState] (via `Navigator.of(context).overlay`) to insert the
/// foreground push-notification card into from outside the widget tree --
/// `WidgetsBinding.instance.rootElement` cannot resolve an Overlay ancestor
/// (it IS the root, so there's nothing above it to search), which silently
/// no-ops and is why foreground notifications stopped appearing.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final authState = ref.read(mobileAuthProvider);
      final location = state.uri.toString();

      // Public routes that don't require authentication
      final publicRoutes = [
        AppRoutes.splash,
        AppRoutes.landing,
        AppRoutes.login,
        AppRoutes.register,
        AppRoutes.forgotPassword,
        AppRoutes.onboarding,
      ];
      final isInterviewRoute = location.startsWith('/interview');
      final isPublicRoute = publicRoutes.contains(location) || isInterviewRoute;

      // Interview room is open to candidates, external evaluators, and mentors directly via room code
      if (isInterviewRoute) return null;

      // While loading, don't redirect anywhere — wait for the check to finish.
      if (authState.isLoading) return null;

      // Not logged in: send to login if trying to access a protected route.
      if (!authState.isLoggedIn) {
        return isPublicRoute ? null : AppRoutes.login;
      }

      // Logged in: if on a public auth route, send to home (or payment).
      if (isPublicRoute && location != AppRoutes.splash) {
        return null; // let them stay on landing/login if they navigated there
      }

      final user = authState.user;
      // Use paymentRequired — the authoritative flag set by the backend
      // (StudentPaymentInfo.isPaymentDue = ONLINE method AND not paid).
      // Falls back to individual field checks for older accounts.
      final needsPayment = user != null &&
          user.role == 'STUDENT' &&
          (user.paymentRequired ||
              (user.paymentMethod == 'ONLINE' &&
               user.paymentStatus != 'COMPLETED'));

      if (!needsPayment) return null;

      // Already on the payment screen — don't redirect.
      if (location.startsWith('/payment')) return null;
      // Sending the student anywhere else would let them bypass the payment.
      return AppRoutes.paymentFor(user.planId ?? 0);
    },
    routes: [
      _animatedRoute(path: AppRoutes.splash, builder: (context, state) => const SplashScreen()),
      _animatedRoute(path: AppRoutes.landing, builder: (context, state) => const LandingScreen()),
      _animatedRoute(path: AppRoutes.login, builder: (context, state) => const LoginScreen()),
      _animatedRoute(path: AppRoutes.register, builder: (context, state) => const RegisterScreen()),
      _animatedRoute(path: AppRoutes.forgotPassword, builder: (context, state) => const ForgotPasswordScreen()),
      _animatedRoute(path: AppRoutes.onboarding, builder: (context, state) => const OnboardingScreen()),
      ShellRoute(
        builder: (context, state, child) => MainShellScreen(child: child),
        routes: [
          _animatedRoute(path: '/notes', builder: (context, state) => const NotesScreen(lessonId: 0)),
          _animatedRoute(path: AppRoutes.notes, builder: (context, state) => NotesScreen(lessonId: int.tryParse(state.pathParameters['lessonId'] ?? '') ?? 0)),
          _animatedRoute(path: AppRoutes.home, builder: (context, state) => const HomeScreen()),
          _animatedRoute(path: AppRoutes.courses, builder: (context, state) => const CoursesScreen()),
          _animatedRoute(path: AppRoutes.courseDetail, builder: (context, state) => CourseDetailScreen(id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0)),
          _animatedRoute(path: AppRoutes.profile, builder: (context, state) => const ProfileScreen()),
          _animatedRoute(path: AppRoutes.notifications, builder: (context, state) => const NotificationsScreen()),
          _animatedRoute(path: AppRoutes.settings, builder: (context, state) => const SettingsScreen()),
          _animatedRoute(path: AppRoutes.placementDrives, builder: (context, state) => PlacementDrivesScreen(initialFilter: _placementFilter(state.uri.queryParameters['filter']))),
          _animatedRoute(path: AppRoutes.calendar, builder: (context, state) => const CalendarScreen()),
          _animatedRoute(path: AppRoutes.assignments, builder: (context, state) => const AssignmentsScreen()),
          _animatedRoute(path: AppRoutes.exams, builder: (context, state) => const ExamsScreen()),
          _animatedRoute(path: AppRoutes.certificates, builder: (context, state) => const CertificatesScreen()),
          _animatedRoute(path: AppRoutes.resumeBuilder, builder: (context, state) => const ResumeBuilderScreen()),
          _animatedRoute(path: AppRoutes.discussion, builder: (context, state) => DiscussionScreen(lessonId: int.tryParse(state.pathParameters['lessonId'] ?? '') ?? 0)),
          _animatedRoute(path: AppRoutes.search, builder: (context, state) => const SearchScreen()),
          _animatedRoute(path: AppRoutes.subscription, builder: (context, state) => const SubscriptionScreen()),
          _animatedRoute(path: AppRoutes.paymentHistory, builder: (context, state) => const PaymentHistoryScreen()),
          _animatedRoute(path: AppRoutes.attendance, builder: (context, state) => const AttendanceScreen()),
          _animatedRoute(path: AppRoutes.feedback, builder: (context, state) => const FeedbackScreen()),
          _animatedRoute(path: AppRoutes.interviewHistory, builder: (context, state) => const InterviewHistoryScreen()),
          _animatedRoute(path: AppRoutes.bookmarks, builder: (context, state) => const BookmarksScreen()),
          _animatedRoute(path: AppRoutes.leaderboard, builder: (context, state) => const LeaderboardScreen()),
          _animatedRoute(path: AppRoutes.dailyChallenge, builder: (context, state) => const DailyChallengeScreen()),
          _animatedRoute(path: AppRoutes.qa, builder: (context, state) => const QaScreen()),
          _animatedRoute(path: AppRoutes.companyQuestions, builder: (context, state) => const CompanyQuestionsScreen()),
          _animatedRoute(path: AppRoutes.supportRequest, builder: (context, state) => const SupportRequestScreen()),
          _animatedRoute(path: AppRoutes.sectionLessons, builder: (context, state) => CourseSectionLessonsScreen(sectionId: int.tryParse(state.pathParameters['sectionId'] ?? '') ?? 0)),
          _animatedRoute(path: AppRoutes.lesson, builder: (context, state) => LessonPlayerScreen(lessonId: int.tryParse(state.pathParameters['lessonId'] ?? '') ?? 0)),
          _animatedRoute(path: AppRoutes.chat, builder: (context, state) => const ChatScreen()),
          _animatedRoute(path: AppRoutes.mentorChat, builder: (context, state) => ChatScreen(mentorId: int.tryParse(state.pathParameters['mentorId'] ?? '') ?? 0)),
        ],
      ),
      _animatedRoute(path: AppRoutes.inAppBrowser, builder: (context, state) => InAppBrowserScreen(
        url: state.uri.queryParameters['url'] ?? '',
        title: state.uri.queryParameters['title'] ?? 'Browser',
      )),
      // Outside the shell: a paper in progress should not show the bottom nav.
      _animatedRoute(
        path: AppRoutes.assessmentPaper,
        builder: (context, state) => AssessmentPaperScreen(
          type: state.pathParameters['type'] ?? 'assignments',
          assessmentId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
          title: state.uri.queryParameters['title'] ?? 'Question Paper',
          durationMinutes: int.tryParse(state.uri.queryParameters['duration'] ?? ''),
          totalMarks: int.tryParse(state.uri.queryParameters['marks'] ?? ''),
        ),
      ),
      _animatedRoute(path: AppRoutes.payment, builder: (context, state) => PaymentScreen(planId: int.tryParse(state.pathParameters['planId'] ?? '') ?? 0)),
      GoRoute(
        path: '/interview',
        redirect: (context, state) {
          final queryCode = state.uri.queryParameters['roomCode'] ?? state.uri.queryParameters['code'];
          if (queryCode != null && queryCode.trim().isNotEmpty) {
            return AppRoutes.interviewRoomFor(queryCode.trim());
          }
          return AppRoutes.interviewHistory;
        },
      ),
      // Outside the shell: full-screen 1-on-1 interview room (video call + live collaborative code editor)
      _animatedRoute(
        path: AppRoutes.interviewRoom,
        builder: (context, state) => InterviewRoomScreen(
          roomCode: state.pathParameters['roomCode'] ?? 'AXIS-DEMO',
        ),
      ),
      _animatedRoute(
        path: '/interview/:roomCode/',
        builder: (context, state) => InterviewRoomScreen(
          roomCode: state.pathParameters['roomCode'] ?? 'AXIS-DEMO',
        ),
      ),
    ],
    errorBuilder: (context, state) {
      // Auto-recovery: If user arrived at any /interview/<code...> URL or fragment (e.g. from web hash routing)
      final candidates = [
        state.uri.toString(),
        state.uri.path,
        state.matchedLocation,
        Uri.base.toString(),
        Uri.base.fragment,
        Uri.base.path,
      ];
      for (final raw in candidates) {
        if (raw.contains('interview/')) {
          final parts = raw.split('interview/');
          if (parts.length > 1) {
            final code = parts[1].split('?').first.split('#').first.split('&').first.split('/').first.trim();
            if (code.isNotEmpty) {
              return InterviewRoomScreen(roomCode: code);
            }
          }
        }
      }

      return Scaffold(
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
      );
    },
  );
});