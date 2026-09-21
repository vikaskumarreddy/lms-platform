import 'dart:math' as math;
import 'package:lms_student_app/presentation/screens/notes/notes_screen.dart';
import 'package:lms_student_app/core/widgets/common_header.dart';
import 'package:lms_student_app/presentation/screens/notes/study_topics.dart';
import 'package:lms_student_app/core/providers/org_theme_provider.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lms_student_app/core/constants/routes.dart';
import 'package:lms_student_app/core/providers/data_providers.dart';
import 'package:lms_student_app/data/models/placement_drive_model.dart';
import 'package:lms_student_app/presentation/screens/main_shell_screen.dart';
import 'package:lms_student_app/presentation/screens/placement/placement_drives_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lms_student_app/presentation/widgets/modern_bottom_nav_bar.dart';

void main() {
  testWidgets('Notes renders common GlassHeader and shared ModernBottomNavBar',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(initialLocation: '/notes/0', routes: [
      ShellRoute(
          builder: (_, __, child) => MainShellScreen(child: child),
          routes: [
            GoRoute(
                path: AppRoutes.notes,
                builder: (_, __) => const NotesScreen(lessonId: 0)),
            GoRoute(
                path: AppRoutes.profile,
                builder: (_, __) =>
                    const Scaffold(body: Text('Profile destination'))),
          ]),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(overrides: [
      userProfileProvider.overrideWith((ref) async => {'name': 'Test Student'}),
      notesProvider.overrideWith((ref) async => <Map<String, dynamic>>[]),
      studyTopicsProvider.overrideWith((ref) async => <Map<String, dynamic>>[]),
      orgNameProvider.overrideWith((ref) async => 'Axisora'),
    ], child: MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();
    expect(find.byType(GlassHeader), findsOneWidget);
    expect(find.byKey(const ValueKey('notes-navigation')), findsOneWidget);
    expect(find.byType(ModernBottomNavBar), findsOneWidget);
    expect(find.text('TS'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsOneWidget);
    expect(find.text('Test Student'), findsOneWidget);
    await tester.tap(find.text('Test Student'));
    await tester.pumpAndSettle();
    expect(find.text('Profile destination'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final width in [390.0, 1024.0]) {
    testWidgets('Placements shell navigation at $width', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router =
          GoRouter(initialLocation: AppRoutes.placementDrives, routes: [
        ShellRoute(
            builder: (_, __, child) => MainShellScreen(child: child),
            routes: [
              GoRoute(
                  path: AppRoutes.placementDrives,
                  builder: (_, __) => const PlacementDrivesScreen()),
              GoRoute(
                  path: AppRoutes.profile,
                  builder: (_, __) =>
                      const Scaffold(body: Text('Profile destination'))),
            ])
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(overrides: [
        userProfileProvider.overrideWith((ref) async => {'name': 'Student'}),
        placementDrivesProvider
            .overrideWith((ref) async => <PlacementDriveModel>[]),
        placementOverviewProvider
            .overrideWith((ref) async => <String, dynamic>{}),
        placementMetricsProvider
            .overrideWith((ref) async => <String, double>{}),
      ], child: MaterialApp.router(routerConfig: router)));
      await tester.pumpAndSettle();
      final bar = find.byType(ModernBottomNavBar);
      expect(bar, findsOneWidget);
      expect(tester.getRect(bar).bottom, lessThanOrEqualTo(900));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Profile destination'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  for (final width in [320.0, 430.0, 1024.0]) {
    testWidgets('Navigation stays compact at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var selected = -1;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
        bottomNavigationBar: ModernBottomNavBar(
            currentIndex: 2,
            tabs: const [
              ('/', Icons.home, Icons.home, 'Home'),
              ('/courses', Icons.book, Icons.book, 'Courses'),
              ('/placements', Icons.work, Icons.work, 'Placements'),
              (
                '/calendar',
                Icons.calendar_month,
                Icons.calendar_month,
                'Calendar'
              ),
              ('/profile', Icons.person, Icons.person, 'Profile')
            ],
            onTap: (index) => selected = index),
      )));
      final bar = find.byType(ModernBottomNavBar);
      expect(bar, findsOneWidget);
      await tester.scrollUntilVisible(
        find.byIcon(Icons.person),
        50,
        scrollable: find.descendant(
          of: bar,
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.person));
      await tester.pumpAndSettle();
      expect(selected, 4);
      expect(tester.takeException(), isNull);
    });
  }
}
