import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lms_student_app/core/providers/data_providers.dart';
import 'package:lms_student_app/presentation/screens/attendance/attendance_screen.dart';
import 'package:lms_student_app/core/widgets/common_header.dart';

void main() {
  final testAttendanceData = {
    'summary': {
      'totalSessions': 10,
      'attendedSessions': 8,
      'attendancePercentage': 80.0,
    },
    'history': [
      // Daily attendance records
      {
        'id': 'd1',
        'eventType': 'DAILY_ATTENDANCE',
        'eventTitle': 'Daily Attendance',
        'startTime': '2026-09-01T09:00:00.000Z',
        'present': true,
        'subject': 'Daily Routine',
        'remarks': 'On time',
      },
      {
        'id': 'd2',
        'eventType': 'DAILY_ATTENDANCE',
        'eventTitle': 'Daily Attendance',
        'startTime': '2026-09-02T09:00:00.000Z',
        'present': false,
        'subject': 'Daily Routine',
        'remarks': 'Sick leave',
      },
      {
        'id': 'd3',
        'eventType': 'CLASS',
        'eventTitle': 'Java Theory Class',
        'startTime': '2026-08-15T10:00:00.000Z',
        'present': true,
      },
      // Event attendance records
      {
        'id': 'e1',
        'eventType': 'WORKSHOP',
        'eventTitle': 'Flutter Masterclass',
        'startTime': '2026-09-05T14:00:00.000Z',
        'present': true,
        'subject': 'Cross-Platform UI',
      },
      {
        'id': 'e2',
        'eventType': 'HACKATHON',
        'eventTitle': 'CodeSprint 2026',
        'startTime': '2026-09-10T11:00:00.000Z',
        'present': false,
      },
    ],
  };

  testWidgets('AttendanceScreen renders Daily and Event sections with bar graphs and calendars',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          attendanceHistoryProvider
              .overrideWith((ref) async => testAttendanceData),
        ],
        child: const MaterialApp(
          home: AttendanceScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Header rendered with GlassHeader and subtitle 'ATTENDANCE'
    expect(find.byType(GlassHeader), findsOneWidget);
    expect(find.text('ATTENDANCE'), findsOneWidget);

    // 2. Both Category Titles rendered: Daily Attendance & Event Attendance
    expect(find.text('Daily Attendance'), findsOneWidget);
    expect(find.text('Event Attendance'), findsOneWidget);

    // 3. Monthly Breakdown (Bar Graph) tiles rendered for both categories
    expect(find.text('Monthly Breakdown'), findsNWidgets(2));
    expect(find.text('Total Days vs Attended Days'), findsNWidgets(2));
    expect(find.text('Total Days'), findsNWidgets(2));
    expect(find.text('Attended Days'), findsNWidgets(2));

    // 4. Month labels rendered in the bar graphs (Jan .. Dec)
    expect(find.text('Jan'), findsAtLeastNWidgets(2));
    expect(find.text('Sep'), findsAtLeastNWidgets(2));

    // 5. Calendar Tiles rendered with legend items
    expect(find.text('Present'), findsAtLeastNWidgets(2));
    expect(find.text('Absent'), findsAtLeastNWidgets(2));
    expect(find.text('Normal Day'), findsNWidgets(2));

    // 6. Day cell interaction: tap a day in the calendar to open bottom sheet
    final dayOneFinder = find.byKey(const Key('calendar_day_daily_1'));
    await tester.ensureVisible(dayOneFinder);
    await tester.tap(dayOneFinder);
    await tester.pumpAndSettle();

    // Bottom sheet shows details for that day
    expect(find.textContaining('Daily Routine'), findsOneWidget);
  });

  testWidgets('AttendanceScreen renders responsive side-by-side layout on wide screens',
      (tester) async {
    // Wide screen (tablet / desktop >= 800px)
    tester.view.physicalSize = const Size(1024, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          attendanceHistoryProvider
              .overrideWith((ref) async => testAttendanceData),
        ],
        child: const MaterialApp(
          home: AttendanceScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Both categories exist side by side
    expect(find.text('Daily Attendance'), findsOneWidget);
    expect(find.text('Event Attendance'), findsOneWidget);
  });
}
