import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lms_student_app/core/providers/data_providers.dart';
import 'package:lms_student_app/data/models/placement_drive_model.dart';
import 'package:lms_student_app/presentation/screens/placement/placement_drives_screen.dart';

void main() {
  for (final statusCode in [200, 500]) {
    testWidgets('Apply through real ApiService: HTTP $statusCode',
        (tester) async {
      SharedPreferences.setMockInitialValues(
          {'userId': 7, 'access_token': 'test-session'});
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return http.Response(
            statusCode == 200 ? '{"status":"APPLIED"}' : '{"error":"Failed"}',
            statusCode,
            headers: {'content-type': 'application/json'});
      });
      addTearDown(client.close);
      await http.runWithClient(() async {
        await tester.pumpWidget(ProviderScope(overrides: [
          placementDrivesProvider.overrideWith((ref) async => [
                PlacementDriveModel(
                  id: 42,
                  companyName: 'Example employer',
                  role: 'Developer',
                  description: 'Full role description',
                  eligibility: 'Final year students',
                )
              ]),
          placementOverviewProvider
              .overrideWith((ref) async => <String, dynamic>{}),
          placementMetricsProvider
              .overrideWith((ref) async => <String, double>{}),
        ], child: const MaterialApp(home: PlacementDrivesScreen())));
        await tester.pumpAndSettle();
        expect(find.text('Full role description'), findsNothing);
        await tester.tap(find.text('Example employer'));
        await tester.pumpAndSettle();
        expect(find.text('Full role description'), findsOneWidget);
        await tester.tap(find.text('Apply now'));
        await tester.pumpAndSettle();
        expect(requests, hasLength(1));
        expect(requests.single.method, 'POST');
        expect(requests.single.url.path, '/api/student-placements/apply');
        expect(requests.single.headers['Authorization'], 'Bearer test-session');
        expect(jsonDecode(requests.single.body), {'userId': 7, 'driveId': 42});
        if (statusCode == 200) {
          expect(find.text('APPLIED'), findsWidgets);
          final button = tester.widget<FilledButton>(
              find.widgetWithText(FilledButton, 'APPLIED'));
          expect(button.onPressed, isNull);
          expect(
              find.text('Application submitted successfully.'), findsOneWidget);
        } else {
          expect(find.text('Apply now'), findsOneWidget);
          expect(
              find.text(
                  'Application could not be submitted. Please try again.'),
              findsOneWidget);
          expect(
              tester
                  .widget<FilledButton>(
                      find.widgetWithText(FilledButton, 'Apply now'))
                  .onPressed,
              isNotNull);
        }
        expect(tester.takeException(), isNull);
      }, () => client);
    });
  }
}
