import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/routes.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/common_header.dart';

final studentDashboardProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getStudentDashboard();
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryColor = const Color(0xFF0F172A);
    final secondaryColor = const Color(0xFFEAB308);
    final profileAsync = ref.watch(userProfileProvider);
    final dashboardAsync = ref.watch(studentDashboardProvider);

    final profile = profileAsync.asData?.value;
    final rawName = (profile?['name'] as String?)?.trim();
    final displayName = (rawName == null || rawName.isEmpty) ? 'Student' : rawName;
    final planName = (profile?['planName'] as String?) ?? 'Free';
    final isActive = profile?['isActive'] != false;

    final dashboard = dashboardAsync.asData?.value ?? const {};
    final attendancePercent = ((dashboard['attendancePercent'] as num?) ?? 0).round();
    final progressPercent = ((dashboard['progressPercent'] as num?) ?? 0).round();
    final performancePercent = ((dashboard['performancePercent'] as num?) ?? 0).round();

    return Scaffold(
      appBar: CommonHeader(
        title: 'Home',
        actions: [
          IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () => context.go(AppRoutes.notifications)),
          IconButton(icon: const Icon(Icons.person_outline), onPressed: () => context.go(AppRoutes.profile)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [primaryColor, primaryColor.withOpacity(0.8)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Welcome, $displayName!', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                Text(planName, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
                const SizedBox(height: 12),
                Row(children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: isActive ? secondaryColor : Colors.grey, borderRadius: BorderRadius.circular(12)), child: Text(isActive ? 'Active' : 'Inactive', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: _StatCard(title: 'Attendance', value: '$attendancePercent%', icon: Icons.check_circle, color: Colors.green, subtitle: 'Classes attended')),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(title: 'Progress', value: '$progressPercent%', icon: Icons.trending_up, color: secondaryColor, subtitle: 'Course')),
          ]),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: _StatCard(title: 'Performance', value: '$performancePercent%', icon: Icons.star, color: Colors.blue, subtitle: 'Graded assignments & exams')),
          const SizedBox(height: 20),
          Consumer(builder: (context, ref, _) {
            final overviewAsync = ref.watch(placementOverviewProvider);
            final overview = overviewAsync.asData?.value ?? const {};
            final totalPosted = ((overview['totalPosted'] as num?) ?? 0).toInt();
            final openCount = ((overview['openCount'] as num?) ?? 0).toInt();
            final appliedCount = ((overview['appliedCount'] as num?) ?? 0).toInt();
            final selectedCount = ((overview['selectedCount'] as num?) ?? 0).toInt();
            return Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Placement Overview', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: primaryColor)),
              const SizedBox(height: 4),
              Text('$totalPosted drives posted since you joined', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _PlacementStatBar(label: 'Open', value: openCount, total: totalPosted, color: Colors.grey),
                _PlacementStatBar(label: 'Applied', value: appliedCount, total: totalPosted, color: secondaryColor),
                _PlacementStatBar(label: 'Selected', value: selectedCount, total: totalPosted, color: Colors.green),
              ]),
            ])));
          }),
          const SizedBox(height: 20),
          Text('Quick Links', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: primaryColor)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _QuickLinkCard(title: 'Courses', icon: Icons.book, color: Colors.blue, onTap: () => context.go(AppRoutes.courses))),
            const SizedBox(width: 12),
            Expanded(child: _QuickLinkCard(title: 'Placements', icon: Icons.work, color: Colors.green, onTap: () => context.go(AppRoutes.placementDrives))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _QuickLinkCard(title: 'Calendar', icon: Icons.calendar_today, color: secondaryColor, onTap: () => context.go(AppRoutes.calendar))),
            const SizedBox(width: 12),
            Expanded(child: _QuickLinkCard(title: 'Bookmarks', icon: Icons.bookmark, color: Colors.purple, onTap: () => context.go(AppRoutes.bookmarks))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _QuickLinkCard(title: 'Assignments', icon: Icons.assignment, color: Colors.indigo, onTap: () => context.go(AppRoutes.assignments))),
            const SizedBox(width: 12),
            Expanded(child: _QuickLinkCard(title: 'Exams', icon: Icons.assignment, color: Colors.orange, onTap: () => context.go(AppRoutes.exams))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _QuickLinkCard(title: 'Q&A', icon: Icons.forum, color: Colors.teal, onTap: () => context.go(AppRoutes.qa))),
            const SizedBox(width: 12),
            Expanded(child: _QuickLinkCard(title: 'Certificates', icon: Icons.workspace_premium, color: Colors.amber, onTap: () => context.go(AppRoutes.certificates))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _QuickLinkCard(title: 'Attendance', icon: Icons.fact_check, color: Colors.brown, onTap: () => context.go(AppRoutes.attendance))),
            const SizedBox(width: 12),
            Expanded(child: _QuickLinkCard(title: 'Notes', icon: Icons.notes, color: Colors.lightBlue, onTap: () => context.go(AppRoutes.notes.replaceAll(':lessonId', '101')))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _QuickLinkCard(title: 'Resume', icon: Icons.description, color: Colors.green, onTap: () => context.go(AppRoutes.resumeBuilder))),
            const SizedBox(width: 12),
            Expanded(child: _QuickLinkCard(title: 'Settings', icon: Icons.settings, color: Colors.blueGrey, onTap: () => context.go(AppRoutes.settings))),
          ]),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title; final String value; final IconData icon; final Color color; final String subtitle;
  const _StatCard({required this.title, required this.value, required this.icon, required this.color, required this.subtitle});
  @override Widget build(BuildContext context) {
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)), Icon(icon, color: color, size: 20)]),
      const SizedBox(height: 8),
      Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: color)),
      Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
    ])));
  }
}

class _QuickLinkCard extends StatelessWidget {
  final String title; final IconData icon; final Color color; final VoidCallback onTap;
  const _QuickLinkCard({required this.title, required this.icon, required this.color, required this.onTap});
  @override Widget build(BuildContext context) {
    return Card(child: InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap, child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [Icon(icon, color: color, size: 32), const SizedBox(height: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.w500))]))));
  }
}

class _PlacementStatBar extends StatelessWidget {
  final String label;
  final int value;
  final int total;
  final Color color;
  const _PlacementStatBar({required this.label, required this.value, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      CircleAvatar(radius: 24, backgroundColor: color.withOpacity(0.15), child: Text('$value', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16))),
      const SizedBox(height: 6),
      Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
    ]);
  }
}