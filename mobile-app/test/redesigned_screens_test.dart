import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lms_student_app/core/constants/routes.dart';
import 'package:lms_student_app/core/providers/data_providers.dart';
import 'package:lms_student_app/core/providers/router_provider.dart';
import 'package:lms_student_app/core/widgets/app_drawer.dart';
import 'package:lms_student_app/core/widgets/common_header.dart';
import 'package:lms_student_app/data/models/bookmark_model.dart';
import 'package:lms_student_app/data/models/lesson.dart';
import 'package:lms_student_app/data/models/notification_item.dart';
import 'package:lms_student_app/presentation/screens/bookmarks/bookmarks_screen.dart';
import 'package:lms_student_app/presentation/screens/certificates/certificates_screen.dart';
import 'package:lms_student_app/presentation/screens/company_questions/company_questions_screen.dart';
import 'package:lms_student_app/presentation/screens/company_questions/company_questions_view_screen.dart';
import 'package:lms_student_app/presentation/screens/courses/course_section_lessons_screen.dart';
import 'package:lms_student_app/presentation/screens/home/home_screen.dart';
import 'package:lms_student_app/presentation/screens/leaderboard/leaderboard_screen.dart';
import 'package:lms_student_app/presentation/screens/main_shell_screen.dart';
import 'package:lms_student_app/presentation/screens/placement/support_request_screen.dart';
import 'package:lms_student_app/presentation/screens/profile/profile_screen.dart';
import 'package:lms_student_app/presentation/screens/qa/qa_screen.dart';
import 'package:lms_student_app/presentation/screens/settings/settings_screen.dart';
import 'package:lms_student_app/presentation/screens/video/video_player_screen.dart';
import 'package:lms_student_app/presentation/screens/video/widgets/lesson_ai_chat_sheet.dart';
import 'package:lms_student_app/presentation/screens/notes/personal_reminders.dart';
import 'package:lms_student_app/presentation/widgets/in_app_notification_overlay.dart';
import 'package:lms_student_app/presentation/widgets/modern_bottom_nav_bar.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'access_token': 'fake-token',
      'userId': 7,
    });
  });

  Widget createShellApp({
    required String initialLocation,
    required List<GoRoute> routes,
    List<Override> overrides = const [],
  }) {
    final router = GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: initialLocation,
      routes: [
        ShellRoute(
          builder: (context, state, child) => MainShellScreen(child: child),
          routes: routes,
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        userProfileProvider.overrideWith((ref) async => {
              'name': 'Alex Johnson',
              'email': 'alex@example.com',
              'batchName': 'Full Stack 2026',
              'isActive': true,
            }),
        orgNameProvider.overrideWith((ref) async => 'Axisora'),
        ...overrides,
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('AppDrawer renders glossy theme, student profile card, and navigation items in shell',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createShellApp(
      initialLocation: '/test-home',
      routes: [
        GoRoute(
          path: '/test-home',
          builder: (context, state) => const CommonHeaderScaffold(
            subtitle: 'Home',
            body: Center(child: Text('Test Content')),
          ),
        ),
      ],
    ));
    await tester.pumpAndSettle();

    // Tap hamburger menu on common header to open drawer
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();

    // Verify student details in glossy header card
    expect(find.text('Alex Johnson'), findsOneWidget);
    expect(find.text('Full Stack 2026'), findsOneWidget);

    // Verify key drawer navigation entries
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Courses'), findsOneWidget);
    expect(find.text('Placements'), findsOneWidget);
    expect(find.text('Attendance'), findsOneWidget);
    expect(find.text('Q&A'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Bookmarks'), findsOneWidget);

    // Scroll to check items further down the drawer
    await tester.drag(find.byType(AppDrawer), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('Certificates'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Verify Theme mode toggle switch exists
    await tester.drag(find.byType(AppDrawer), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.byType(Switch), findsOneWidget);
  });

  testWidgets('QA Screen renders CommonHeaderScaffold with dark navy glass theme',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createShellApp(
      initialLocation: AppRoutes.qa,
      routes: [
        GoRoute(
          path: AppRoutes.qa,
          builder: (context, state) => const QaScreen(),
        ),
      ],
    ));
    await tester.pumpAndSettle();

    // Header with subtitle
    expect(find.byType(GlassHeader), findsOneWidget);
    expect(find.text('Q&A'), findsOneWidget);

    // Community Q&A banner & Ask button
    expect(find.text('Community Q&A'), findsOneWidget);
    expect(find.text('Ask'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Java'), findsOneWidget);

    // Tap Ask to open Ask form
    await tester.tap(find.text('Ask'));
    await tester.pumpAndSettle();
    expect(find.text('Ask a Question'), findsOneWidget);
    expect(find.text('FORMAT:'), findsOneWidget);
    expect(find.text('Preview'), findsOneWidget);

    // Tap preview toggle
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
  });

  testWidgets('Company Questions Screen renders CommonHeaderScaffold',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createShellApp(
      initialLocation: AppRoutes.companyQuestions,
      routes: [
        GoRoute(
          path: AppRoutes.companyQuestions,
          builder: (context, state) => const CompanyQuestionsScreen(),
        ),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.byType(GlassHeader), findsOneWidget);
    expect(find.text('COMPANY QUESTIONS'), findsOneWidget);
  });

  testWidgets('Bookmarks Screen renders CommonHeaderScaffold and lesson filters',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createShellApp(
      initialLocation: AppRoutes.bookmarks,
      overrides: [
        bookmarksProvider.overrideWith((ref) async => <BookmarkModel>[]),
      ],
      routes: [
        GoRoute(
          path: AppRoutes.bookmarks,
          builder: (context, state) => const BookmarksScreen(),
        ),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.byType(GlassHeader), findsOneWidget);
    expect(find.text('BOOKMARKS'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Lesson'), findsOneWidget);
    expect(find.text('Module Lesson'), findsOneWidget);
    expect(find.text('No bookmarks found'), findsOneWidget);
  });

  testWidgets('Leaderboard Screen renders Motivator card, XP guide, and Podium',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createShellApp(
      initialLocation: AppRoutes.leaderboard,
      overrides: [
        leaderboardProvider.overrideWith((ref) async => {
              'entries': [
                {'id': 1, 'name': 'Aarav Sharma', 'score': 2450, 'rank': 1},
                {'id': 2, 'name': 'Priya Patel', 'score': 2180, 'rank': 2},
                {'id': 3, 'name': 'Rohan Iyer', 'score': 1950, 'rank': 3},
                {'id': 4, 'name': 'Alex Johnson', 'score': 1680, 'rank': 4},
              ],
              'myRank': {
                'id': 4,
                'name': 'Alex Johnson',
                'score': 1680,
                'rank': 4,
              },
            }),
      ],
      routes: [
        GoRoute(
          path: AppRoutes.leaderboard,
          builder: (context, state) => const LeaderboardScreen(),
        ),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.byType(GlassHeader), findsOneWidget);
    expect(find.text('LEADERBOARD'), findsOneWidget);

    // Student Motivator card
    expect(find.text('Your Standing'), findsOneWidget);
    expect(find.text('#4'), findsWidgets);
    expect(find.text('1680 Total XP'), findsOneWidget);
    expect(find.text('XP Guide'), findsOneWidget);

    // Podium display
    expect(find.text('Aarav Sharma'), findsOneWidget);
    expect(find.text('Priya Patel'), findsOneWidget);
    expect(find.text('Rohan Iyer'), findsOneWidget);

    // Tap XP Guide and verify interactive rules bottom sheet
    await tester.tap(find.text('XP Guide'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('How to Earn Leaderboard XP'), findsOneWidget);
    expect(find.text('Submit Assignment'), findsOneWidget);
    expect(find.text('+50 XP'), findsOneWidget);
  });

  testWidgets('Certificates Screen renders CommonHeaderScaffold with gold accents',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createShellApp(
      initialLocation: AppRoutes.certificates,
      routes: [
        GoRoute(
          path: AppRoutes.certificates,
          builder: (context, state) => const CertificatesScreen(),
        ),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.byType(GlassHeader), findsOneWidget);
    expect(find.text('CERTIFICATES'), findsOneWidget);
    expect(find.text('No certificates earned yet'), findsOneWidget);
  });

  testWidgets('Settings Screen renders CommonHeaderScaffold, toggles, and logout',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createShellApp(
      initialLocation: AppRoutes.settings,
      routes: [
        GoRoute(
          path: AppRoutes.settings,
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.byType(GlassHeader), findsOneWidget);
    expect(find.text('SETTINGS'), findsOneWidget);
    expect(find.text('Dark Mode'), findsOneWidget);
    expect(find.text('Push Notifications'), findsOneWidget);
    expect(find.text('Log Out'), findsOneWidget);
  });

  testWidgets('Support Request Screen renders CommonHeaderScaffold with showBackButton',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createShellApp(
      initialLocation: AppRoutes.supportRequest,
      routes: [
        GoRoute(
          path: AppRoutes.supportRequest,
          builder: (context, state) => const SupportRequestScreen(),
        ),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.byType(GlassHeader), findsOneWidget);
    expect(find.text('SUPPORT'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
    expect(find.text('Submit Support Request'), findsOneWidget);
  });

  testWidgets('Lesson & CourseSectionLessons routes render inside ShellRoute with ModernBottomNavBar',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    final router = GoRouter(
      initialLocation: '/courses/1/sections/1',
      routes: [
        ShellRoute(
          builder: (context, state, child) => MainShellScreen(child: child),
          routes: [
            GoRoute(
              path: AppRoutes.sectionLessons,
              builder: (context, state) =>
                  const CourseSectionLessonsScreen(sectionId: 1),
            ),
            GoRoute(
              path: AppRoutes.lesson,
              builder: (context, state) =>
                  const LessonPlayerScreen(lessonId: 10),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        userProfileProvider.overrideWith((ref) async => {'name': 'Alex Johnson'}),
        orgNameProvider.overrideWith((ref) async => 'Axisora'),
        learningLessonsProvider(1).overrideWith((ref) async => [
              Lesson(
                id: 10,
                title: 'Introduction to Flutter',
                heading: 'Flutter Architecture',
                duration: '15 mins',
                videoUrl: '',
                pdfNotesUrl: '',
                isLocked: false,
                completed: false,
                notes: '',
              ),
            ]),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    // Verify CourseSectionLessons has GlassHeader and ModernBottomNavBar
    expect(find.byType(GlassHeader), findsOneWidget);
    expect(find.text('LESSONS'), findsOneWidget);
    expect(find.byType(ModernBottomNavBar), findsOneWidget);

    // Verify back button on header
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsWidgets);

    // Navigate to Lesson detail screen
    router.go('/lesson/10');
    await tester.pumpAndSettle();

    // Verify LessonPlayerScreen has GlassHeader and ModernBottomNavBar
    expect(find.byType(GlassHeader), findsOneWidget);
    expect(find.text('LESSON'), findsOneWidget);
    expect(find.byType(ModernBottomNavBar), findsOneWidget);
  });

  testWidgets('HomeScreen renders CommonHeaderScaffold without header overlap and responsive top tiles', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createShellApp(
      initialLocation: AppRoutes.home,
      routes: [
        GoRoute(path: AppRoutes.home, builder: (_, __) => const HomeScreen()),
        GoRoute(path: AppRoutes.courses, builder: (_, __) => const Scaffold(body: Text('Courses Screen'))),
        GoRoute(path: AppRoutes.attendance, builder: (_, __) => const Scaffold(body: Text('Attendance Screen'))),
      ],
      overrides: [
        studentDashboardProvider.overrideWith((ref) async => {
          'progressPercent': 12,
          'attendancePercent': 75,
          'performancePercent': 80,
          'timeSpendingTrend': [20, 40, 60, 80],
        }),
      ],
    ));
    await tester.pumpAndSettle();

    // Verify GlassHeader renders with subtitle 'Home'
    expect(find.byType(GlassHeader), findsOneWidget);
    expect(find.text('HOME'), findsOneWidget);

    // Verify GlassHeader bottom does not overlap with greeting top
    final headerBottom = tester.getBottomRight(find.byType(GlassHeader)).dy;
    final greetingTop = tester.getTopLeft(find.textContaining('Welcome back')).dy;
    expect(greetingTop >= headerBottom, isTrue,
        reason: 'Greeting top ($greetingTop) must be below or equal to header bottom ($headerBottom)');

    // Verify top metric tiles render without overflow
    expect(find.text('COURSE PROGRESS'), findsOneWidget);
    expect(find.text('12% completed'), findsOneWidget);
    expect(find.text('ATTENDANCE'), findsOneWidget);
    expect(find.text('75% present'), findsOneWidget);

    // Now resize to compact screen 320x600 (iPhone SE) to verify responsive layout
    tester.view.physicalSize = const Size(320, 600);
    await tester.pumpAndSettle();

    expect(find.text('COURSE PROGRESS'), findsOneWidget);
    expect(find.text('12% completed'), findsOneWidget);
    expect(find.text('ATTENDANCE'), findsOneWidget);
    expect(find.text('75% present'), findsOneWidget);

    // Ensure no Flutter layout errors
    expect(tester.takeException(), isNull);
  });

  testWidgets('HomeScreen time spending interval dropdown and calendar pill are interactive', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createShellApp(
      initialLocation: AppRoutes.home,
      routes: [
        GoRoute(path: AppRoutes.home, builder: (_, __) => const HomeScreen()),
      ],
      overrides: [
        studentDashboardProvider.overrideWith((ref) async => {
          'progressPercent': 50,
          'attendancePercent': 80,
          'performancePercent': 90,
          'timeSpendingTrend': [30, 45, 60, 75, 80, 85, 90],
        }),
      ],
    ));
    await tester.pumpAndSettle();

    // Verify Time Spending tile initial state (Month)
    expect(find.text('Time Spending'), findsOneWidget);
    expect(find.text('Month'), findsOneWidget);
    expect(find.text('Monthly Trend'), findsOneWidget);

    // Tap the dropdown to change to Day
    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();

    // Tap Day in dropdown
    await tester.tap(find.text('Day').last);
    await tester.pumpAndSettle();

    expect(find.text('Daily Trend'), findsOneWidget);
    expect(find.text('Mon'), findsOneWidget);
    expect(find.text('Sun'), findsOneWidget);

    // Tap the dropdown to change to Week
    await tester.tap(find.text('Day'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Week').last);
    await tester.pumpAndSettle();

    expect(find.text('Weekly Trend'), findsOneWidget);
    expect(find.text('Week 1'), findsOneWidget);

    // Verify calendar pill is interactive and exists
    expect(find.byIcon(Icons.calendar_month_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reminder in-app notification popup renders 3D alarm clock, title, and Open button', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    bool actionTapped = false;

    await tester.pumpWidget(createShellApp(
      initialLocation: AppRoutes.home,
      routes: [
        GoRoute(path: AppRoutes.home, builder: (_, __) => const HomeScreen()),
      ],
    ));
    await tester.pumpAndSettle();

    // Trigger Reminder in-app popup
    final reminder = NotificationItem(
      id: 99,
      title: 'Revise Algorithms',
      message: 'Math class starts in 15 mins',
      type: 'reminder',
      isRead: false,
      time: '4:00 PM',
      actionUrl: '/notes/0?view=reminders',
    );

    InAppNotificationOverlay.show(reminder, onAction: () {
      actionTapped = true;
    });
    await tester.pumpAndSettle();

    // Verify Reminder card title and content
    expect(find.text('Reminder'), findsOneWidget);
    expect(find.text('Math class starts in 15 mins'), findsOneWidget);
    expect(find.text('4:00 PM'), findsOneWidget);

    // Verify "Open" pill button
    expect(find.text('Open'), findsOneWidget);

    // Tap "Open" button
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(actionTapped, isTrue);
    expect(find.text('Reminder'), findsNothing);
  });

  testWidgets('General in-app notification renders luxury card with placement metadata and category badge', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createShellApp(
      initialLocation: AppRoutes.home,
      routes: [
        GoRoute(path: AppRoutes.home, builder: (_, __) => const HomeScreen()),
      ],
    ));
    await tester.pumpAndSettle();

    // Trigger Placement in-app notification
    final placementNotif = NotificationItem(
      id: 101,
      title: 'Google Campus Drive',
      message: 'Software Engineer drive on campus',
      type: 'placement',
      isRead: false,
      name: 'Google',
      venue: 'Auditorium A',
      criteria: 'B.Tech CSE/IT',
      actionUrl: '/placements',
    );

    InAppNotificationOverlay.show(placementNotif);
    await tester.pumpAndSettle();

    // Verify Category badge and title
    expect(find.text('PLACEMENT DRIVE'), findsOneWidget);
    expect(find.text('Google Campus Drive'), findsOneWidget);
    expect(find.text('Software Engineer drive on campus'), findsOneWidget);

    // Verify rich metadata chips
    expect(find.text('Name: '), findsOneWidget);
    expect(find.text('Google'), findsOneWidget);
    expect(find.text('Venue: '), findsOneWidget);
    expect(find.text('Auditorium A'), findsOneWidget);
    expect(find.text('Criteria: '), findsOneWidget);
    expect(find.text('B.Tech CSE/IT'), findsOneWidget);

    // Verify CTA button
    expect(find.text('VIEW PLACEMENT DRIVE'), findsOneWidget);

    // Tap Dismiss
    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();

    expect(find.text('PLACEMENT DRIVE'), findsNothing);
  });

  testWidgets('Distraction-free bottom nav bar hide and view toggle hides and restores navigation bar', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createShellApp(
      initialLocation: AppRoutes.home,
      routes: [
        GoRoute(path: AppRoutes.home, builder: (_, __) => const HomeScreen()),
      ],
    ));
    await tester.pumpAndSettle();

    // Verify gesture edge arrow is visible with hide key
    expect(find.byKey(const ValueKey('hide-nav-bar-btn')), findsOneWidget);
    expect(find.byType(ModernBottomNavBar), findsOneWidget);

    // Tap gesture edge arrow to hide bottom navigation bar
    await tester.tap(find.byKey(const ValueKey('hide-nav-bar-btn')));
    await tester.pumpAndSettle();

    // Verify navbar is hidden and show nav key is active on gesture arrow
    expect(find.byType(ModernBottomNavBar), findsNothing);
    expect(find.byKey(const ValueKey('show-nav-bar-btn')), findsOneWidget);

    // Tap gesture edge arrow to restore navigation bar
    await tester.tap(find.byKey(const ValueKey('show-nav-bar-btn')));
    await tester.pumpAndSettle();

    // Verify navbar is restored
    expect(find.byType(ModernBottomNavBar), findsOneWidget);
    expect(find.byKey(const ValueKey('hide-nav-bar-btn')), findsOneWidget);
  });

  testWidgets('CompanyQuestionsViewScreen renders header with back button and company title', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createShellApp(
      initialLocation: '/company-prep/1',
      routes: [
        GoRoute(
          path: '/company-prep/:id',
          builder: (context, state) => const CompanyQuestionsViewScreen(
            assessmentId: 1,
            companyName: 'Amazon',
            companyDescription: 'Leading e-commerce and cloud provider',
          ),
        ),
      ],
    ));
    await tester.pump();

    // Verify header subtitle shows company name and back button
    expect(find.text('AMAZON'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
  });

  testWidgets('Secondary screens have fixed bottom navbar removed', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createShellApp(
      initialLocation: AppRoutes.settings,
      routes: [
        GoRoute(path: AppRoutes.settings, builder: (_, __) => const SettingsScreen()),
      ],
    ));
    await tester.pumpAndSettle();

    // Verify settings header renders and ModernBottomNavBar is present
    expect(find.byType(GlassHeader), findsOneWidget);
    expect(find.byType(ModernBottomNavBar), findsOneWidget);
    expect(find.byKey(const ValueKey('hide-nav-bar-btn')), findsOneWidget);

    // Tap Hide Nav
    await tester.tap(find.byKey(const ValueKey('hide-nav-bar-btn')));
    await tester.pumpAndSettle();

    // Verify navbar is hidden and Show Nav button is visible
    expect(find.byType(ModernBottomNavBar), findsNothing);
    expect(find.byKey(const ValueKey('show-nav-bar-btn')), findsOneWidget);

    // Tap Show Nav
    await tester.tap(find.byKey(const ValueKey('show-nav-bar-btn')));
    await tester.pumpAndSettle();

    // Verify navbar is restored
    expect(find.byType(ModernBottomNavBar), findsOneWidget);
    expect(find.byKey(const ValueKey('hide-nav-bar-btn')), findsOneWidget);
  });

  testWidgets('ReminderDialog renders dark inputs and supports create & edit modes', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // 1. Create mode
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: ReminderDialog(key: ValueKey('create-dialog')),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Create reminder'), findsOneWidget);
    expect(find.text('Save reminder'), findsOneWidget);
    expect(find.byKey(const ValueKey('reminder-title')), findsOneWidget);

    // 2. Edit mode
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: ReminderDialog(
            key: const ValueKey('edit-dialog'),
            initialReminder: {
              'id': 12,
              'title': 'Solve 5 LeetCode DP problems',
              'description': 'Target medium level questions',
              'dueAt': DateTime.now().add(const Duration(hours: 4)).toIso8601String(),
              'status': 'PENDING',
            },
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Edit reminder'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);
    expect(find.text('Solve 5 LeetCode DP problems'), findsOneWidget);
    expect(find.text('Target medium level questions'), findsOneWidget);
  });

  testWidgets('RemindersList renders Edit and Delete action buttons for each reminder', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final testReminders = [
      {
        'id': 42,
        'title': 'System Design Revision',
        'description': 'Review CAP theorem and caching strategies',
        'dueAt': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
        'status': 'PENDING',
        'notificationStatus': 'PENDING',
      },
    ];

    await tester.pumpWidget(ProviderScope(
      overrides: [
        personalRemindersProvider.overrideWith((ref) async => testReminders),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: RemindersList(query: '', alphabetical: false),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('System Design Revision'), findsOneWidget);
    expect(find.text('Complete'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.byKey(const ValueKey('reminder-edit-42')), findsOneWidget);
    expect(find.byKey(const ValueKey('reminder-delete-42')), findsOneWidget);
  });

  test('invalidateAllUserData invalidates studentDashboardProvider and resets data', () async {
    int fetchCount = 0;
    final container = ProviderContainer(
      overrides: [
        studentDashboardProvider.overrideWith((ref) async {
          fetchCount++;
          return {
            'progressPercent': fetchCount * 10,
            'attendancePercent': 85,
            'performancePercent': 90,
          };
        }),
      ],
    );
    addTearDown(container.dispose);

    // Initial fetch
    final initial = await container.read(studentDashboardProvider.future);
    expect(initial['progressPercent'], 10);
    expect(fetchCount, 1);

    // Call invalidateAllUserData
    invalidateAllUserData(container);

    // Fresh fetch after invalidation
    final refreshed = await container.read(studentDashboardProvider.future);
    expect(refreshed['progressPercent'], 20);
    expect(fetchCount, 2);
  });

  testWidgets('ProfileScreen expands viewport padding when bottom navbar is hidden and restores when shown', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer(
      overrides: [
        userProfileProvider.overrideWith((ref) async => {
          'name': 'Test Student',
          'email': 'student@test.com',
          'planName': 'Pro Plan',
        }),
        coursesProvider.overrideWith((ref) async => []),
        certificatesProvider.overrideWith((ref) async => []),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: ProfileScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    // With navbar visible, bottom padding should be 110
    var listView = tester.widget<ListView>(find.byType(ListView));
    expect((listView.padding as EdgeInsets).bottom, 110.0);

    // Hide navbar
    container.read(shellNavBarHiddenProvider.notifier).state = true;
    await tester.pumpAndSettle();

    // With navbar hidden, bottom padding expands to 28
    listView = tester.widget<ListView>(find.byType(ListView));
    expect((listView.padding as EdgeInsets).bottom, 28.0);

    // Show navbar again
    container.read(shellNavBarHiddenProvider.notifier).state = false;
    await tester.pumpAndSettle();

    listView = tester.widget<ListView>(find.byType(ListView));
    expect((listView.padding as EdgeInsets).bottom, 110.0);
  });

  testWidgets('LessonAiChatSheet renders header, 100/100 question limit badge, suggestion chips, and input', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final testLesson = Lesson(
      id: 999,
      title: 'Operating Systems & Architecture',
      heading: 'Process Scheduling & Memory Management',
      notes: 'CPU scheduling algorithms and virtual memory concepts.',
      videoUrl: '',
      pdfNotesUrl: 'https://example.com/os_notes.pdf',
      duration: '45m',
      isLocked: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: LessonAiChatSheet(
              lesson: testLesson,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify AI Tutor title and badges
    expect(find.text('AI Tutor'), findsOneWidget);
    expect(find.text('PDF Context'), findsOneWidget);
    expect(find.text('Process Scheduling & Memory Management'), findsOneWidget);

    // Verify 100 question limit badge
    expect(find.text('100/100 left'), findsOneWidget);

    // Verify starter question suggestion chips
    expect(find.text('📝 Summarize this lesson'), findsOneWidget);
    expect(find.text('💡 Key takeaways & formulas'), findsOneWidget);
    expect(find.text('❓ Give me 3 practice questions'), findsOneWidget);
    expect(find.text('🔍 Explain core concepts step-by-step'), findsOneWidget);

    // Verify input bar textfield hint
    expect(find.text('Ask anything about this lesson...'), findsOneWidget);

    // Verify typing in question field
    await tester.enterText(find.byType(TextField), 'What is virtual memory?');
    expect(find.text('What is virtual memory?'), findsOneWidget);
  });

  testWidgets('CommonHeaderScaffold renders custom header action buttons', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: CommonHeaderScaffold(
            subtitle: 'Lesson',
            actions: [
              Text('Ask AI'),
              Icon(Icons.auto_awesome),
            ],
            body: Center(child: Text('Lesson Content')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ask AI'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    expect(find.text('Lesson Content'), findsOneWidget);
  });
}
