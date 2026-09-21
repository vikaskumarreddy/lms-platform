import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lms_student_app/core/providers/data_providers.dart';
import 'package:lms_student_app/presentation/screens/notes/notes_screen.dart';
import 'package:lms_student_app/presentation/screens/notes/notes_workspace.dart';

import 'package:lms_student_app/core/providers/org_theme_provider.dart';

void main() {
  for (final success in [true, false]) {
    testWidgets(
        'Topic creation and top tab persistence: HTTP ${success ? 200 : 500}',
        (tester) async {
      SharedPreferences.setMockInitialValues(
          {'userId': 7, 'access_token': 'test-session'});
      final topics = <Map<String, dynamic>>[];
      final writes = <http.Request>[];
      final client = MockClient((request) async {
        if (request.url.path != '/api/study-topics') {
          return http.Response('{}', 404);
        }
        if (request.method == 'GET') {
          return http.Response(jsonEncode(topics), 200);
        }
        writes.add(request);
        if (!success) return http.Response('{}', 500);
        final input = jsonDecode(request.body) as Map<String, dynamic>;
        final topic = <String, dynamic>{
          'id': 12,
          'title': input['title'],
          'createdAt': '2026-09-17T12:00:00',
          'updatedAt': '2026-09-17T12:00:00',
          'version': 0,
        };
        topics.add(topic);
        return http.Response(jsonEncode(topic), 200);
      });
      addTearDown(client.close);
      await http.runWithClient(() async {
        await tester.pumpWidget(ProviderScope(overrides: [
          notesProvider.overrideWith((ref) async => <Map<String, dynamic>>[]),
          userProfileProvider
              .overrideWith((ref) async => {'name': 'Test Student'}),
          orgNameProvider.overrideWith((ref) async => 'Axisora'),
        ], child: const MaterialApp(home: NotesScreen(lessonId: 0))));
        await tester.pumpAndSettle();
        expect(find.byType(NotesWorkspace), findsOneWidget);
        await tester.tap(find.byTooltip('Create topic'));
        await tester.pumpAndSettle();
        await tester.enterText(
            find.byKey(const ValueKey('topic-title')), '  Flutter basics  ');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', 'test-session');
        await tester.tap(find.text('Save topic'));
        await tester.pumpAndSettle();
        expect(writes, hasLength(1));
        expect(writes.single.method, 'POST');
        expect(writes.single.headers['Authorization'], 'Bearer test-session');
        expect(jsonDecode(writes.single.body), {'title': 'Flutter basics'});
        if (success) {
          expect(find.text('Save topic'), findsNothing);
          expect(find.text('Flutter basics'), findsOneWidget);
          expect(find.byTooltip('Create topic'), findsOneWidget);
          // Changing tabs must not discard the persisted topic.
          await tester.tap(find.byTooltip('Todo'));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Notes'));
          await tester.pumpAndSettle();
          expect(find.text('Flutter basics'), findsOneWidget);
        } else {
          expect(find.text('Save topic'), findsOneWidget);
          expect(find.text('Could not save topic. Please try again.'),
              findsOneWidget);
          expect(
              tester
                  .widget<TextField>(find.byKey(const ValueKey('topic-title')))
                  .controller!
                  .text,
              '  Flutter basics  ');
        }
        expect(tester.takeException(), isNull);
      }, () => client);
    });
  }
}
