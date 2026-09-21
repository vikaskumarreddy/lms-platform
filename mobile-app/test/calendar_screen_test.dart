import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lms_student_app/core/providers/data_providers.dart';
import 'package:lms_student_app/core/widgets/common_header.dart';
import 'package:lms_student_app/data/models/event_model.dart';
import 'package:lms_student_app/presentation/screens/calendar/calendar_screen.dart';
import 'package:lms_student_app/presentation/screens/main_shell_screen.dart';
import 'package:lms_student_app/presentation/widgets/modern_bottom_nav_bar.dart';

final calendarEventsProvider = FutureProvider<List<EventModel>>((ref) async => []);
final calendarAttendanceProvider = FutureProvider<Map<int, bool>>((ref) async => {});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Widget tests otherwise substitute Ahem (black blocks) for real fonts.
    final configFile = File('.dart_tool/package_config.json').absolute;
    final config = jsonDecode(await configFile.readAsString()) as Map;
    final flutter = (config['packages'] as List)
        .cast<Map>()
        .firstWhere((package) => package['name'] == 'flutter');
    final rootUri = configFile.uri.resolve(flutter['rootUri'] as String);
    final flutterRoot =
        Uri.parse('${rootUri.toString().replaceFirst(RegExp(r'/+$'), '')}/');
    final fonts =
        flutterRoot.resolve('../../bin/cache/artifacts/material_fonts/');
    for (final entry in {
      'Roboto': ['roboto-regular.ttf', 'roboto-bold.ttf'],
      'MaterialIcons': ['materialicons-regular.otf'],
    }.entries) {
      final loader = FontLoader(entry.key);
      for (final name in entry.value) {
        loader.addFont(File.fromUri(fonts.resolve(name))
            .readAsBytes()
            .then((bytes) => ByteData.sublistView(bytes)));
      }
      await loader.load();
    }
  });
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('Calendar routed layout and controls at $width',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = DateTime.now();
      String at(int h, int m) =>
          DateTime(now.year, now.month, now.day, h, m).toIso8601String();
      final events = [
        EventModel(
            id: 2,
            title: 'Schedule Client Meeting..',
            description: 'Discuss project milestones',
            startTime: at(11, 31),
            endTime: at(13, 0)),
        EventModel(
            id: 1,
            title: '60min Push-up & Stretching Exercise..',
            description: 'Morning session',
            startTime: at(8, 30),
            endTime: at(9, 30)),
        EventModel(
            id: 3,
            title: 'Share Concepts with Dev..',
            description: 'Review',
            startTime: at(14, 30),
            endTime: at(16, 30)),
        EventModel(
            id: 4,
            title: 'Invalid date event',
            description: '',
            startTime: 'invalid'),
      ];
      final router = GoRouter(initialLocation: '/calendar', routes: [
        ShellRoute(
            builder: (_, __, child) => MainShellScreen(child: child),
            routes: [
              GoRoute(
                  path: '/calendar',
                  builder: (_, __) => const CalendarScreen()),
              GoRoute(
                  path: '/profile',
                  builder: (_, __) =>
                      const Scaffold(body: Text('Profile destination'))),
              GoRoute(
                  path: '/notes/:lessonId',
                  builder: (_, state) => Scaffold(
                      body:
                          Text('Notes ${state.uri.queryParameters['view']}'))),
            ]),
      ]);
      addTearDown(router.dispose);
      final boundary = GlobalKey();
      await tester.pumpWidget(ProviderScope(
          overrides: [
            userProfileProvider
                .overrideWith((ref) async => {'name': 'Test Student'}),
            calendarEventsProvider.overrideWith((ref) async => events),
            calendarAttendanceProvider.overrideWith((ref) async => {1: true}),
          ],
          child: RepaintBoundary(
              key: boundary, child: MaterialApp.router(routerConfig: router))));
      await tester.pumpAndSettle();
      expect(find.text('CALENDAR'), findsOneWidget);
      expect(find.byType(ModernBottomNavBar), findsOneWidget);
      final nav = tester.widget<ModernBottomNavBar>(find.byType(ModernBottomNavBar));
      expect(nav.tabs.any((tab) => tab.$4 == 'Calendar'), isTrue);
      expect(nav.tabs[nav.currentIndex].$4, 'Calendar');
      expect(find.byTooltip('Notebooks'), findsNothing);
      expect(find.byTooltip('Create reminder'), findsNothing);
      expect(find.text('Invalid date event'), findsNothing);
      expect(
          tester.getTopLeft(find.byKey(const ValueKey('calendar-event-1'))).dy,
          lessThan(tester
              .getTopLeft(find.byKey(const ValueKey('calendar-event-2')))
              .dy));
      expect(find.text('Break 121m'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (width == 390) {
        await tester.runAsync(() async {
          final image = await (boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('build/calendar-preview.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.tap(find.byKey(const ValueKey('calendar-event-1')));
      await tester.pumpAndSettle();
      expect(find.text('Attended'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('calendar-fab')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('reminder-title')), findsNothing);
      await tester.tap(find.byTooltip('Choose date'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.drag(find.byKey(const ValueKey('calendar-date-strip')),
          const Offset(-70, 0));
      await tester.pumpAndSettle();
      expect(find.text('No events on this day'), findsOneWidget);
      await tester.tap(find.byTooltip('Go to today'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('calendar-event-1')), findsOneWidget);
      await tester.tap(find.byTooltip('Open sidebar'));
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsOneWidget);
      await tester.tapAt(const Offset(15, 400));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Profile destination'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
