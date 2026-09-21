import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lms_student_app/core/constants/routes.dart';
import 'package:lms_student_app/core/widgets/common_header.dart';

/// Focused tests for the reference-style header: a solid navy bar with a
/// left-aligned white title and a gold notification bubble, plus working
/// menu/back actions. The old frosted-glass gradient must be fully gone.
void main() {
  Widget headerScaffold() => Scaffold(
        key: mainScaffoldKey,
        appBar: const CommonHeader(title: 'Home'),
        body: const SizedBox.shrink(),
        drawer: Drawer(
          child: ListView(children: const [
            DrawerHeader(child: Text('Menu')),
            ListTile(title: Text('Drawer item')),
          ]),
        ),
      );

  GoRouter buildRouter() => GoRouter(initialLocation: '/', routes: [
        GoRoute(path: '/', builder: (_, __) => headerScaffold()),
        GoRoute(
            path: AppRoutes.notifications,
            builder: (_, __) => const Scaffold(
                body: Center(child: Text('Notifications page')))),
        GoRoute(
            path: AppRoutes.login,
            builder: (_, __) =>
                const Scaffold(body: Center(child: Text('Login page')))),
      ]);

  testWidgets('Header renders solid navy with white title and gold bell',
      (tester) async {
    final r = buildRouter();
    addTearDown(r.dispose);
    await tester
        .pumpWidget(ProviderScope(child: MaterialApp.router(routerConfig: r)));
    await tester.pumpAndSettle();

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, const Color(0xFF0F172A),
        reason: 'Header strip must be the solid reference navy');
    expect(appBar.centerTitle, isFalse, reason: 'Title sits left, like the reference');
    final title = tester.widget<Text>(find.text('Home'));
    expect(title.style?.color, Colors.white);
    expect(title.style?.fontWeight, FontWeight.bold);

    final bell = tester.widget<Material>(find
        .ancestor(
            of: find.byIcon(Icons.notifications_outlined),
            matching: find.byType(Material))
        .first);
    expect(bell.color, const Color(0xFFEAB308),
        reason: 'Notification action must be the gold bubble');

    // The previous frosted-glass treatment is gone entirely.
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(AnimatedContainer), findsNothing);
    expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Menu icon opens the shared drawer', (tester) async {
    final r = buildRouter();
    addTearDown(r.dispose);
    await tester
        .pumpWidget(ProviderScope(child: MaterialApp.router(routerConfig: r)));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Drawer item'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Bell opens the notifications screen', (tester) async {
    final r = buildRouter();
    addTearDown(r.dispose);
    await tester
        .pumpWidget(ProviderScope(child: MaterialApp.router(routerConfig: r)));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Notifications page'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Back mode shows the back arrow; custom actions replace the bell',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
            home: Scaffold(
                appBar: CommonHeader(
                    title: 'Lesson',
                    showBackButton: true,
                    actions: [
          IconButton(
              icon: const Icon(Icons.support_agent), onPressed: () {}),
        ])))));
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
    expect(find.byIcon(Icons.notifications_outlined), findsNothing);
    expect(find.byIcon(Icons.support_agent), findsOneWidget);
    expect(const CommonHeader(title: 'x').preferredSize.height, kToolbarHeight);
    expect(tester.takeException(), isNull);
  });
}
