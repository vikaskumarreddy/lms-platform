import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lms_student_app/core/providers/data_providers.dart';
import 'package:lms_student_app/presentation/screens/notes/notes_screen.dart';
import 'package:lms_student_app/presentation/screens/notes/personal_reminders.dart';
import 'package:lms_student_app/presentation/screens/notes/study_topics.dart';
import 'package:lms_student_app/core/providers/org_theme_provider.dart';

void main() {
  for (final success in [true, false]) {
    testWidgets('Reminder popup persists and handles errors: $success',
        (tester) async {
      SharedPreferences.setMockInitialValues(
          {'userId': 7, 'access_token': 'test-session'});
      final rows = <Map<String, dynamic>>[];
      final writes = <http.Request>[];
      final client = MockClient((request) async {
        if (!request.url.path.startsWith('/api/personal-reminders')) {
          return http.Response('{}', 404);
        }
        if (request.method == 'GET') {
          return http.Response(jsonEncode(rows), 200);
        }
        writes.add(request);
        if (!success) return http.Response('{}', 500);
        if (request.method == 'POST') {
          rows.add({
            ...jsonDecode(request.body) as Map<String, dynamic>,
            'id': 1,
            'status': 'PENDING',
            'notificationStatus': 'PENDING'
          });
        } else {
          rows.single['status'] = 'COMPLETED';
        }
        return http.Response('{}', 200);
      });
      addTearDown(client.close);
      await http.runWithClient(() async {
        await tester.pumpWidget(ProviderScope(overrides: [
          notesProvider.overrideWith((ref) async => []),
          studyTopicsProvider.overrideWith((ref) async => []),
          userProfileProvider.overrideWith((ref) async => {'name': 'Student'}),
          orgNameProvider.overrideWith((ref) async => 'Axisora'),
        ], child: const MaterialApp(home: NotesScreen(lessonId: 0))));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Reminders'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Create reminder'));
        await tester.pumpAndSettle();
        expect(find.byType(ReminderDialog), findsOneWidget);
        await tester.tap(find.text('Save reminder'));
        await tester.pumpAndSettle();
        expect(writes, isEmpty);
        await tester.enterText(
            find.byKey(const ValueKey('reminder-title')), 'Revise Flutter');
        await tester.tap(find.text('Save reminder'));
        await tester.pumpAndSettle();
        expect(writes.single.url.path, '/api/personal-reminders');
        final body = jsonDecode(writes.single.body) as Map<String, dynamic>;
        expect(DateTime.parse(body['dueAt'] as String).isUtc, isTrue);
        expect(body.containsKey('userId'), isFalse);
        if (success) {
          expect(find.byType(ReminderDialog), findsNothing);
          expect(find.text('Revise Flutter'), findsOneWidget);
          await tester.tap(find.text('Complete'));
          await tester.pumpAndSettle();
          expect(writes.last.method, 'PATCH');
          expect(find.textContaining('COMPLETED'), findsOneWidget);
          // Navigating to Notes tab allows creating a topic
          await tester.tap(find.byTooltip('Notes'));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Create topic'));
          await tester.pumpAndSettle();
          expect(find.byType(StudyTopicDialog), findsOneWidget);
        } else {
          expect(find.text('Could not save reminder. Please try again.'),
              findsOneWidget);
          expect(find.text('Revise Flutter'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      }, () => client);
    });
  }
}
