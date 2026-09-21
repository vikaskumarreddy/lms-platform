import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lms_student_app/core/providers/data_providers.dart';
import 'package:lms_student_app/presentation/screens/profile/profile_screen.dart';
import 'package:lms_student_app/core/widgets/common_header.dart';

void main() {
  final testProfile = {
    'name': 'Vikas Nachireddy',
    'email': 'nachireddyvikas2001@gmail.com',
    'phone': '+91 6304024159',
    'linkedin': 'https://linkedin.com/in/vikas',
    'github': 'https://github.com/vikas',
    'planName': 'Java Placement Program',
    'batchName': 'Batch 0',
  };

  testWidgets('ProfileScreen renders all reference design components',
      (tester) async {
    SharedPreferences.setMockInitialValues({'userId': 1});
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileProvider.overrideWith((ref) async => testProfile),
          coursesProvider.overrideWith((ref) async => []),
          certificatesProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(
          home: ProfileScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Header with GlassHeader
    expect(find.byType(GlassHeader), findsOneWidget);
    expect(find.text('PROFILE'), findsOneWidget);

    // 2. Top Profile Card: Name, Email, Upgrade Plan button
    expect(find.text('Vikas Nachireddy'), findsOneWidget);
    expect(find.text('nachireddyvikas2001@gmail.com'), findsOneWidget);
    expect(find.text('Upgrade Plan'), findsOneWidget);

    // 3. 4 Stats Tiles: Profile Completion, Courses Enrolled, Certificates, Resume Filling
    expect(find.text('Profile Completion'), findsOneWidget);
    expect(find.text('Courses Enrolled'), findsOneWidget);
    expect(find.text('Certificates'), findsOneWidget);
    expect(find.text('Resume Filling'), findsOneWidget);

    // 4. Personal Information Card: View Mode with Phone, LinkedIn, GitHub
    expect(find.text('Personal Information'), findsOneWidget);
    expect(find.text('Phone'), findsOneWidget);
    expect(find.text('+91 6304024159'), findsOneWidget);
    expect(find.text('LinkedIn'), findsOneWidget);
    expect(find.text('GitHub'), findsOneWidget);

    // 5. Subscription Details: Plan, Batch, Status, Payment History
    expect(find.text('Subscription Details'), findsOneWidget);
    expect(find.text('Java Placement Program'), findsOneWidget);
    expect(find.text('Batch 0'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Payment History'), findsOneWidget);

    // 6. 2x2 Quick Actions Grid: My Certificates, Resume Builder, Settings, Logout
    expect(find.text('My Certificates'), findsOneWidget);
    expect(find.text('Resume Builder'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);

    // 7. Toggle Edit Mode
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Save'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(5));
  });
}
