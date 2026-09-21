import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lms_student_app/core/utils/lesson_media.dart';
import 'package:lms_student_app/data/models/placement_drive_model.dart';
import 'package:lms_student_app/presentation/screens/placement/placement_drive_card.dart';

void main() {
  test('Backend media gets session context without leaking it externally', () {
    const base = 'https://academy.example/api';
    final uri = Uri.parse(
        lessonMediaUrl('/api/media/42/serve?x=1', base, token: 'session'));
    expect(uri.path, '/api/media/42/serve');
    expect(uri.queryParameters, {'x': '1', 'token': 'session'});
    expect(
        lessonMediaUrl('https://cdn.example/video.mp4', base, token: 'session'),
        'https://cdn.example/video.mp4');
  });
  test('YouTube URLs are parsed without a dummy fallback', () {
    expect(youtubeVideoId('https://youtu.be/abcdefghijk?t=5'), 'abcdefghijk');
    expect(youtubeVideoId('https://youtube.com/watch?v=abcdefghijk'),
        'abcdefghijk');
    expect(youtubeVideoId('https://youtube.com/shorts/abcdefghijk'),
        'abcdefghijk');
    expect(youtubeVideoId('https://cdn.example/abcdefghijk'), isNull);
    expect(youtubeVideoId('broken'), isNull);
    expect(videoDocument('https://example.com/a?x="bad"'),
        contains('&quot;bad&quot;'));
  });
  for (final success in [true, false]) {
    testWidgets('Card details and apply result $success', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var calls = 0;
      await tester.pumpWidget(ProviderScope(
          child: MaterialApp(
              home: Scaffold(
        body: PlacementDriveCard(
          drive: PlacementDriveModel(
              id: 42,
              companyName: 'Example Company',
              role: 'Developer',
              description: 'Full opportunity description',
              eligibility: 'Final year students'),
          status: 'OPEN',
          isEligible: true,
          onApply: () async {
            calls++;
            return success;
          },
          onScheduleSlot: () async {},
        ),
      ))));
      await tester.pumpAndSettle();
      expect(find.text('Full opportunity description'), findsNothing);
      await tester.tap(find.text('Example Company'));
      await tester.pumpAndSettle();
      expect(find.text('Full opportunity description'), findsOneWidget);
      expect(find.text('Final year students'), findsOneWidget);
      await tester.tap(find.text('Apply now'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text(success ? 'APPLIED' : 'Apply now'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}
