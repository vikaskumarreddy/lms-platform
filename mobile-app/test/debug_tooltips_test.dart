import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lms_student_app/core/providers/data_providers.dart';
import 'package:lms_student_app/presentation/screens/notes/notes_screen.dart';
import 'package:lms_student_app/presentation/screens/notes/study_topics.dart';

void main() {
  testWidgets('debug tooltips', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ProviderScope(overrides: [
      studyTopicsProvider.overrideWith((ref) async => []),
      notesProvider.overrideWith((ref) async => []),
      userProfileProvider.overrideWith((ref) async => {'name': 'T'}),
    ], child: const MaterialApp(home: NotesScreen(lessonId: 0))));
    await tester.pumpAndSettle();
    final tips = tester
        .widgetList<Tooltip>(find.byType(Tooltip))
        .map((e) => e.message)
        .toList();
    debugPrint('TOOLTIPS: $tips');
    expect(tips, isNotEmpty);
  });
}
