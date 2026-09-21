import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lms_student_app/core/providers/data_providers.dart';
import 'package:lms_student_app/presentation/screens/notes/notes_screen.dart';
import 'package:lms_student_app/presentation/screens/notes/study_topics.dart';
import 'package:lms_student_app/presentation/screens/notes/personal_reminders.dart';
import 'package:lms_student_app/core/providers/org_theme_provider.dart';

final sampleNotes = [
  {'id': 1, 'title': 'Revision', 'content': 'Dart', 'lessonId': null},
  {'id': 2, 'title': 'Widgets', 'content': 'Layout', 'lessonId': 42},
  {'id': 3, 'title': 'State', 'content': 'providers', 'lessonId': 42},
];

Future<void> mountNotes(WidgetTester t, {double width = 390}) async {
  SharedPreferences.setMockInitialValues(
      {'userId': 7, 'access_token': 'test-session'});
  t.view.physicalSize = Size(width, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(ProviderScope(overrides: [
    studyTopicsProvider.overrideWith((ref) async => []),
    notesProvider.overrideWith((ref) async => sampleNotes),
    userProfileProvider.overrideWith((ref) async => {'name': 'Test Student'}),
    orgNameProvider.overrideWith((ref) async => 'Axisora'),
    personalRemindersProvider.overrideWith((ref) async => []),
  ], child: const MaterialApp(home: NotesScreen(lessonId: 42))));
  await t.pumpAndSettle();
}

Future<void> openNotebooks(WidgetTester t) async {
  await t.tap(find.byTooltip('Notebooks'));
  await t.pumpAndSettle();
}

void main() {
  for (final width in [320.0, 390.0, 1024.0]) {
    testWidgets('Notebook layout, grouping and search at $width',
        (tester) async {
      await mountNotes(tester, width: width);
      await openNotebooks(tester);
      expect(find.text('General Notes'), findsOneWidget);
      expect(find.text('Lesson 42'), findsOneWidget);
      expect(find.textContaining('2 Notes'), findsOneWidget);
      expect(find.byKey(const ValueKey('notes-navigation')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Lesson 42'));
      await tester.pumpAndSettle();
      expect(find.text('Widgets'), findsOneWidget);
      expect(find.text('Revision'), findsNothing);
      await tester.tap(find.byTooltip('Search notes'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'providers');
      await tester.pumpAndSettle();
      expect(find.text('State'), findsOneWidget);
      expect(find.text('Widgets'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Create note HTTP 200', (tester) async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response('{"id":4}', 200);
    });
    addTearDown(client.close);
    await http.runWithClient(() async {
      await mountNotes(tester);
      await openNotebooks(tester);
      await tester.tap(find.text('General Notes'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('New Note'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Saved title');
      await tester.enterText(find.byType(TextField).last, 'Saved content');
      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();
      expect(requests, hasLength(1));
      expect(requests.single.method, 'POST');
      expect(requests.single.url.path, '/api/notes');
      expect(requests.single.headers['Authorization'], 'Bearer test-session');
      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body['title'], 'Saved title');
      expect(body['lessonId'], isNull);
      expect(find.byTooltip('Save'), findsNothing);
      expect(tester.takeException(), isNull);
    }, () => client);
  });

  testWidgets('Notes open on notebook cards', (tester) async {
    final client = MockClient((request) async {
      return http.Response('{}', 200);
    });
    addTearDown(client.close);
    await http.runWithClient(() async {
      await mountNotes(tester);
      await openNotebooks(tester);
      expect(find.text('Revision'), findsNothing);
      expect(find.text('General Notes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => client);
  });

  testWidgets('Delete is confirmed and failed deletion is reported',
      (tester) async {
    final client = MockClient((request) async {
      if (request.method == 'DELETE') return http.Response('{}', 500);
      return http.Response('{}', 200);
    });
    addTearDown(client.close);
    await http.runWithClient(() async {
      await mountNotes(tester);
      await openNotebooks(tester);
      await tester.tap(find.text('General Notes'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete note').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('permanently deleted'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Could not delete note. Please try again.'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => client);
  });
}
