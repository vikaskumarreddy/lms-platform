import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/routes.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/providers/org_theme_provider.dart';
import '../../../core/widgets/common_header.dart';
import '../../../core/widgets/charts.dart';
import '../../../data/models/mentor_model.dart';

export '../../../core/providers/data_providers.dart'
    show studentDashboardProvider, interviewHistoryProvider;

/// Pixel-faithful recreation of the supplied dark analytics dashboard.
/// The composition intentionally keeps the reference's dense card grid and
/// visual hierarchy, while collapsing cleanly to two columns on narrow phones.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  DateTimeRange? _selectedDateRange;

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(orgThemeProvider);
    final profile = ref.watch(userProfileProvider).asData?.value;
    final dashboard = ref.watch(studentDashboardProvider).asData?.value ?? const {};
    final rawName = (profile?['name'] as String?)?.trim();
    final name = rawName == null || rawName.isEmpty ? 'Student' : rawName;
    final progress = ((dashboard['progressPercent'] as num?) ?? 0).toDouble();
    final attendance = ((dashboard['attendancePercent'] as num?) ?? 0).toDouble();
    final performance = ((dashboard['performancePercent'] as num?) ?? 0).toDouble();
    // "Time Spending" is driven by the recorded study sessions when any exist;
    // the backend falls back to the real graded-marks/attendance curve otherwise,
    // so this series is never a fabricated line.
    final trend = ((dashboard['timeSpendingTrend'] ??
                dashboard['performanceTrend'] ??
                const []) as List)
        .whereType<num>()
        .map((value) => (value.toDouble() / 100).clamp(0.0, 1.0))
        .toList();
    final courses = ref.watch(coursesProvider).asData?.value ?? const [];
    final assignments = ref.watch(assignmentsProvider).asData?.value ?? const [];
    final exams = ref.watch(examsProvider).asData?.value ?? const [];
    final mentors = ref.watch(mentorsProvider).asData?.value ?? const <MentorModel>[];
    final events = ref.watch(myUpcomingEventsProvider).asData?.value ?? const [];
    final attendanceHistory = ref.watch(attendanceHistoryProvider).asData?.value ?? const {};
    final placementOverview = ref.watch(placementOverviewProvider).asData?.value ?? const {};
    final interviewHistory = ref.watch(interviewHistoryProvider).asData?.value ?? const [];

    return CommonHeaderScaffold(
      backgroundColor: const Color(0xFF071D43),
      subtitle: 'Home',
      body: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final isNavBarHidden = ref.watch(shellNavBarHiddenProvider);
        return ListView(
          padding: EdgeInsets.fromLTRB(18, 18, 18, isNavBarHidden ? 28 : 118),
          children: [
            _ReferenceGreeting(theme: theme, name: name),
            const SizedBox(height: 18),
            _ReferenceMetricRow(theme: theme, progress: progress, attendance: attendance,
                onCourses: () => context.go(AppRoutes.courses),
                onAttendance: () => context.go(AppRoutes.attendance)),
            const SizedBox(height: 16),
            _ReferenceFilterBar(
              theme: theme,
              selectedDateRange: _selectedDateRange,
              onDateRangeChanged: (range) {
                setState(() => _selectedDateRange = range);
              },
            ),
            const SizedBox(height: 10),
            _ReferenceAnalyticsGrid(
              theme: theme,
              wide: wide,
              progress: progress,
              attendance: attendance,
              performance: performance,
              trend: trend,
              mentors: mentors,
              selectedDateRange: _selectedDateRange,
            ),
            const SizedBox(height: 10),
            _AssessmentPerformanceRow(theme: theme, assignments: assignments, exams: exams),
            const SizedBox(height: 10),
            _ReferenceCourseRow(theme: theme, courses: courses),
            const SizedBox(height: 10),
            _ReferenceScheduleCard(theme: theme, events: events),
            const SizedBox(height: 10),
            _ReferenceLowerGrid(theme: theme, wide: wide, attendanceHistory: attendanceHistory, placementOverview: placementOverview, interviewCount: interviewHistory.length),
            const SizedBox(height: 14),
            _ReferenceQuickActions(theme: theme, wide: wide),
          ],
        );
      }),
    );
  }
}

// --------------------------------------------------------------- section 1

/// A wide progress chip like the "Video Editing / 3D Motion" tiles: icon,
/// title, subtitle and a ring showing the percentage.
class _ProgressChip extends StatelessWidget {
  final dynamic theme;
  final String label;
  final String sub;
  final double percent;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  const _ProgressChip({
    required this.theme,
    required this.label,
    required this.sub,
    required this.percent,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlossyCard(
      baseColor: theme.surface,
      opacity: 0.9,
      padding: const EdgeInsets.all(12),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
                color: color.withOpacity(0.18), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label.toUpperCase(),
                      style: TextStyle(
                          fontSize: 9.5,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w700,
                          color: theme.textSecondary)),
                  const SizedBox(height: 2),
                  Text(sub,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: theme.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ]),
          ),
          const SizedBox(width: 6),
          RingProgress(
              percent: percent,
              color: color,
              track: theme.divider,
              textColor: theme.textPrimary,
              size: 42,
              strokeWidth: 5),
        ]),
      ),
    );
  }
}

/// "Time Spending" panel: smooth line chart over the performance trend with
/// a highlighted peak tooltip, plus the current month label.
class _TimeSpendingCard extends StatelessWidget {
  final dynamic theme;
  final List<double> trend;
  final double performance;
  const _TimeSpendingCard(
      {required this.theme, required this.trend, required this.performance});

  String get _monthLabel {
    const months = [
      'January','February','March','April','May','June',
      'July','August','September','October','November','December'
    ];
    return months[DateTime.now().month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final peak = trend.isEmpty
        ? 0.0
        : trend.reduce((a, b) => a > b ? a : b) * 100;
    return GlossyCard(
      baseColor: theme.surface,
      opacity: 0.9,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Time Spending',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: theme.textPrimary)),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: theme.divider.withOpacity(0.4),
                borderRadius: BorderRadius.circular(12)),
            child: Text(_monthLabel,
                style: TextStyle(
                    fontSize: 11, color: theme.textSecondary)),
          ),
        ]),
        const SizedBox(height: 4),
        Text('Learning activity trend',
            style: TextStyle(fontSize: 11.5, color: theme.textSecondary)),
        const SizedBox(height: 8),
        Stack(children: [
          MiniLineChart(
              values: trend,
              lineColor: theme.info,
              fillColor: theme.info,
              height: 110),
          if (trend.length >= 3)
            Positioned(
              top: 0,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: theme.success,
                    borderRadius: BorderRadius.circular(10)),
                child: Text('${peak.round()}%',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: theme.onPrimary)),
              ),
            ),
        ]),
        const SizedBox(height: 4),
        Text('Overall performance: ${performance.round()}%',
            style: TextStyle(fontSize: 11.5, color: theme.textSecondary)),
      ]),
    );
  }
}

/// "Your Progress" panel: a donut of the total achievement with a breakdown
/// of Progress / Attendance / Performance rows beside it.
class _YourProgressCard extends StatelessWidget {
  final dynamic theme;
  final double progress;
  final double attendance;
  final double performance;
  const _YourProgressCard({
    required this.theme,
    required this.progress,
    required this.attendance,
    required this.performance,
  });

  @override
  Widget build(BuildContext context) {
    return GlossyCard(
      baseColor: theme.surface,
      opacity: 0.9,
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Your Progress',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: theme.textPrimary)),
        const SizedBox(height: 2),
        Text('Your total course progress here',
            style: TextStyle(fontSize: 11.5, color: theme.textSecondary)),
        const SizedBox(height: 14),
        Row(children: [
          DonutChart(
            size: 110,
            strokeWidth: 15,
            track: theme.divider,
            segments: [
              (progress.clamp(0.001, double.infinity), theme.accent),
              (attendance.clamp(0.0, double.infinity), theme.primary),
              (performance.clamp(0.0, double.infinity), theme.success),
            ],
            center: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Total',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.textPrimary)),
                  Text('Achievement',
                      style: TextStyle(
                          fontSize: 9, color: theme.textSecondary)),
                ]),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(children: [
              _LegendRow(
                  theme: theme,
                  color: theme.accent,
                  label: 'Course Progress',
                  value: '${progress.round()}%'),
              const SizedBox(height: 8),
              _LegendRow(
                  theme: theme,
                  color: theme.primary,
                  label: 'Attendance',
                  value: '${attendance.round()}%'),
              const SizedBox(height: 8),
              _LegendRow(
                  theme: theme,
                  color: theme.success,
                  label: 'Performance',
                  value: '${performance.round()}%'),
            ]),
          ),
        ]),
      ]),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final dynamic theme;
  final Color color;
  final String label;
  final String value;
  const _LegendRow({
    required this.theme,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Expanded(
          child: Text(label,
              style: TextStyle(fontSize: 12.5, color: theme.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis)),
      Text(value,
          style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: theme.textPrimary)),
    ]);
  }
}

/// "Attendance" panel: monthly present-rate bar chart derived from the
/// student's attendance history (grouped per month client-side).
class _AttendanceCard extends ConsumerWidget {
  const _AttendanceCard();

  Future<Map<int, List<bool>>> _monthly(WidgetRef ref) async {
    final data = await ref.read(attendanceHistoryProvider.future);
    final history = (data['history'] as List?) ?? const [];
    final map = <int, List<bool>>{};
    for (final item in history) {
      if (item is! Map) continue;
      // The backend exposes the class date under `startTime`; `date`/`at`/
      // `markedAt` are kept as fallbacks for tolerance.
      final dateStr = (item['startTime'] ??
              item['date'] ??
              item['at'] ??
              item['markedAt'] ??
              '')
          .toString();
      final date = DateTime.tryParse(dateStr);
      if (date == null) continue;
      final present = (item['present'] ?? item['isPresent'] ?? false) == true;
      map.putIfAbsent(date.month, () => []).add(present);
    }
    return map;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(orgThemeProvider);
    return GlossyCard(
      baseColor: theme.surface,
      opacity: 0.9,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Attendance',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: theme.textPrimary)),
          const Spacer(),
          _DotLabel(theme: theme, color: theme.success, label: 'Present'),
          const SizedBox(width: 10),
          _DotLabel(theme: theme, color: theme.error, label: 'Absent'),
        ]),
        const SizedBox(height: 14),
        FutureBuilder<Map<int, List<bool>>>(
          future: _monthly(ref),
          builder: (context, snap) {
            final monthly = snap.data ?? const {};
            const months = ['J','F','M','A','M','J','J','A','S','O','N','D'];
            final currentMonth = DateTime.now().month;
            return SizedBox(
              height: 130,
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(12, (i) {
                    final records = monthly[i + 1] ?? const [];
                    final pct = records.isEmpty
                        ? 0.0
                        : records.where((p) => p).length / records.length;
                    final isCurrent = (i + 1) == currentMonth;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: FractionallySizedBox(
                                    heightFactor: records.isEmpty
                                        ? 0.04
                                        : pct.clamp(0.08, 1.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: isCurrent
                                            ? theme.accent
                                            : theme.info.withOpacity(
                                                records.isEmpty ? 0.15 : 0.55),
                                        borderRadius:
                                            BorderRadius.circular(5),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(months[i],
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: theme.textSecondary)),
                            ]),
                      ),
                    );
                  })),
            );
          },
        ),
      ]),
    );
  }
}

class _DotLabel extends StatelessWidget {
  final dynamic theme;
  final Color color;
  final String label;
  const _DotLabel(
      {required this.theme, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(fontSize: 10.5, color: theme.textSecondary)),
    ]);
  }
}

/// "Upcoming" panel: next exams and assignments (closest deadlines first),
/// mirroring the reference "Upcoming Courses" schedule list.
class _UpcomingCard extends ConsumerWidget {
  const _UpcomingCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(orgThemeProvider);
    final examsAsync = ref.watch(examsProvider);
    final assignmentsAsync = ref.watch(assignmentsProvider);

    final items = <(String, String, IconData, Color)>[];
    for (final e in (examsAsync.asData?.value ?? const [])) {
      items.add((e.title, e.formattedDate, Icons.quiz_rounded, theme.info));
    }
    for (final a in (assignmentsAsync.asData?.value ?? const [])) {
      items.add((a.title, a.formattedDueDate, Icons.assignment_rounded,
          theme.accent));
    }
    items.sort((a, b) => a.$2.compareTo(b.$2));
    final top = items.take(3).toList();

    return GlossyCard(
      baseColor: theme.surface,
      opacity: 0.9,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Upcoming',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: theme.textPrimary)),
          const Spacer(),
          InkWell(
            onTap: () => context.go(AppRoutes.calendar),
            child: Text('See all',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.accent)),
          ),
        ]),
        const SizedBox(height: 12),
        if (top.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text('Nothing due right now â€” great job!',
                style:
                    TextStyle(fontSize: 12.5, color: theme.textSecondary)),
          )
        else
          ...top.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: item.$4.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(item.$3, color: item.$4, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.$1,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: theme.textPrimary)),
                          Text(item.$2,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: theme.textSecondary)),
                        ]),
                  ),
                ]),
              )),
      ]),
    );
  }
}

// --------------------------------------------------------------- section 2

/// The "Placement Dashboard" section (adapted from the hiring-dashboard
/// reference): 4 stat tiles, pipeline-stage bars and a top-companies donut.
class _PlacementDashboardSection extends ConsumerWidget {
  const _PlacementDashboardSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(orgThemeProvider);
    final overviewAsync = ref.watch(placementOverviewProvider);
    final drivesAsync = ref.watch(placementDrivesProvider);
    final interviewsAsync = ref.watch(interviewHistoryProvider);

    final overview = overviewAsync.asData?.value ?? const {};
    final openCount = ((overview['openCount'] as num?) ?? 0).toInt();
    final appliedCount = ((overview['appliedCount'] as num?) ?? 0).toInt();
    final selectedCount = ((overview['selectedCount'] as num?) ?? 0).toInt();
    final totalPosted = ((overview['totalPosted'] as num?) ?? 0).toInt();
    final interviewCount = (interviewsAsync.asData?.value ?? const []).length;

    // Top companies by number of open drives (adapted "Top Sources" donut).
    final drives = drivesAsync.asData?.value ?? const [];
    final byCompany = <String, int>{};
    for (final d in drives) {
      final company = d.companyName.trim();
      if (company.isEmpty) continue;
      byCompany[company] = (byCompany[company] ?? 0) + 1;
    }
    final topCompanies = (byCompany.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(3)
        .toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: theme.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.work_rounded, color: theme.primary, size: 20),
        ),
        const SizedBox(width: 10),
        Text('Placement Dashboard',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: theme.textPrimary)),
      ]),
      const SizedBox(height: 12),

      // ---- 4 stat tiles ----
      Row(children: [
        Expanded(
            child: _StatTile(
          theme: theme,
          icon: Icons.folder_open_rounded,
          label: 'Open Drives',
          value: '$openCount',
          sub: '$totalPosted posted',
          color: theme.primary,
        )),
        const SizedBox(width: 10),
        Expanded(
            child: _StatTile(
          theme: theme,
          icon: Icons.description_rounded,
          label: 'Applications',
          value: '$appliedCount',
          sub: 'by you',
          color: theme.accent,
        )),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
            child: _StatTile(
          theme: theme,
          icon: Icons.people_rounded,
          label: 'Interviews',
          value: '$interviewCount',
          sub: 'scheduled',
          color: theme.info,
        )),
        const SizedBox(width: 10),
        Expanded(
            child: _StatTile(
          theme: theme,
          icon: Icons.verified_rounded,
          label: 'Offers',
          value: '$selectedCount',
          sub: 'selected',
          color: theme.success,
        )),
      ]),
      const SizedBox(height: 14),

      // ---- pipeline stages ----
      _PipelineCard(
        theme: theme,
        stages: [
          ('Applied', appliedCount, theme.info),
          ('Interviews', interviewCount, theme.accent),
          ('Offers', selectedCount, theme.success),
        ],
      ),
      const SizedBox(height: 14),

      // ---- top companies donut ----
      if (topCompanies.isNotEmpty)
        _TopCompaniesCard(theme: theme, companies: topCompanies),
    ]);
  }
}

class _StatTile extends StatelessWidget {
  final dynamic theme;
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final Color color;
  const _StatTile({
    required this.theme,
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlossyCard(
      baseColor: theme.surface,
      opacity: 0.9,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: color.withOpacity(0.16),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: TextStyle(fontSize: 11.5, color: theme.textSecondary)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: theme.textPrimary)),
        const SizedBox(height: 2),
        Text(sub, style: TextStyle(fontSize: 10.5, color: color)),
      ]),
    );
  }
}

/// Horizontal stage bars (Applied / Interviews / Offers) like the reference
/// "Pipeline Stage" panel.
class _PipelineCard extends StatelessWidget {
  final dynamic theme;
  final List<(String, int, Color)> stages;
  const _PipelineCard({required this.theme, required this.stages});

  @override
  Widget build(BuildContext context) {
    final maxVal = stages.fold<int>(1, (m, s) => math.max(m, s.$2));
    return GlossyCard(
      baseColor: theme.surface,
      opacity: 0.9,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Pipeline Stage',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: theme.textPrimary)),
        const SizedBox(height: 12),
        ...stages.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                SizedBox(
                    width: 76,
                    child: Text(s.$1,
                        style: TextStyle(
                            fontSize: 12, color: theme.textSecondary))),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Stack(children: [
                      Container(
                          height: 16,
                          color: theme.divider.withOpacity(0.35)),
                      FractionallySizedBox(
                        widthFactor: (s.$2 / maxVal).clamp(0.02, 1.0),
                        child: Container(height: 16, color: s.$3),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${s.$2}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.textPrimary)),
              ]),
            )),
      ]),
    );
  }
}

/// Top companies donut (adapted "Top Sources" panel): share of open drives
/// per company.
class _TopCompaniesCard extends StatelessWidget {
  final dynamic theme;
  final List<MapEntry<String, int>> companies;
  const _TopCompaniesCard({required this.theme, required this.companies});

  @override
  Widget build(BuildContext context) {
    final colors = [theme.primary, theme.accent, theme.info];
    final total = companies.fold<int>(0, (s, c) => s + c.value);
    return GlossyCard(
      baseColor: theme.surface,
      opacity: 0.9,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Top Companies',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: theme.textPrimary)),
        const SizedBox(height: 12),
        Row(children: [
          DonutChart(
            size: 92,
            strokeWidth: 14,
            track: theme.divider,
            segments: List.generate(
                companies.length,
                (i) => (companies[i].value.toDouble(),
                    colors[i % colors.length])),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(companies.length, (i) {
                  final pct = total == 0
                      ? 0
                      : (companies[i].value * 100 / total).round();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                              color: colors[i % colors.length],
                              shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(companies[i].key,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: theme.textSecondary))),
                      Text('$pct%',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: theme.textPrimary)),
                    ]),
                  );
                })),
          ),
        ]),
      ]),
    );
  }
}

// --------------------------------------------------------------- quick links

/// Quick-links grid. Each tile's accent color is derived purely from the org
/// theme â€” cycled across tiles so the grid reads as varied/colorful.
class _QuickLinksGrid extends StatelessWidget {
  final dynamic theme;
  const _QuickLinksGrid({required this.theme});

  @override
  Widget build(BuildContext context) {
    final palette = <Color>[
      theme.primary,
      theme.accent,
      theme.info,
      theme.success,
      Color.alphaBlend(Colors.white.withOpacity(0.25), theme.primary),
      Color.alphaBlend(Colors.black.withOpacity(0.15), theme.accent),
      Color.alphaBlend(Colors.white.withOpacity(0.2), theme.info),
      Color.alphaBlend(Colors.black.withOpacity(0.12), theme.success),
      Color.alphaBlend(Colors.white.withOpacity(0.35), theme.primary),
      Color.alphaBlend(Colors.black.withOpacity(0.1), theme.info),
    ];
    final items = <(String, IconData, String)>[
      ('Courses', Icons.menu_book_rounded, AppRoutes.courses),
      ('Placements', Icons.work_rounded, AppRoutes.placementDrives),
      ('Calendar', Icons.calendar_today_rounded, AppRoutes.calendar),
      ('Bookmarks', Icons.bookmark_rounded, AppRoutes.bookmarks),
      ('Assignments', Icons.assignment_rounded, AppRoutes.assignments),
      ('Exams', Icons.quiz_rounded, AppRoutes.exams),
      ('Q&A', Icons.forum_rounded, AppRoutes.qa),
      ('Certificates', Icons.workspace_premium_rounded, AppRoutes.certificates),
      ('Attendance', Icons.fact_check_rounded, AppRoutes.attendance),
      ('Notes', Icons.notes_rounded, AppRoutes.notes.replaceAll(':lessonId', '101')),
      ('Leaderboard', Icons.leaderboard_rounded, AppRoutes.leaderboard),
      ('Resume', Icons.description_rounded, AppRoutes.resumeBuilder),
      ('Settings', Icons.settings_rounded, AppRoutes.settings),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.6),
      itemBuilder: (context, index) {
        final item = items[index];
        return _QuickLinkTile(
          theme: theme,
          title: item.$1,
          icon: item.$2,
          color: palette[index % palette.length],
          onTap: () => context.go(item.$3),
        );
      },
    );
  }
}

class _QuickLinkTile extends StatelessWidget {
  final dynamic theme;
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QuickLinkTile({
    required this.theme,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlossyCard(
      baseColor: theme.surface,
      opacity: 0.88,
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.16), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(title,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.textPrimary))),
            ]),
          ),
        ),
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// Reference dashboard composition
class _ReferenceGreeting extends StatelessWidget {
  final dynamic theme;
  final String name;
  const _ReferenceGreeting({required this.theme, required this.name});

  @override
  Widget build(BuildContext context) => Row(children: [
        const Text('👋', style: TextStyle(fontSize: 31)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Hi, $name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text('Welcome back to your dashboard',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.white.withOpacity(.75), fontSize: 14)),
          ]),
        ),
      ]);
}

class _ReferenceMetricRow extends StatelessWidget {
  final dynamic theme;
  final double progress;
  final double attendance;
  final VoidCallback onCourses;
  final VoidCallback onAttendance;
  const _ReferenceMetricRow({
    required this.theme,
    required this.progress,
    required this.attendance,
    required this.onCourses,
    required this.onAttendance,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 260) {
            return Column(
              children: [
                _ReferenceMetric(
                  theme: theme,
                  icon: Icons.school_rounded,
                  title: 'COURSE PROGRESS',
                  value: '${progress.round()}% completed',
                  percent: progress,
                  color: const Color(0xFF9652FF),
                  onTap: onCourses,
                ),
                const SizedBox(height: 10),
                _ReferenceMetric(
                  theme: theme,
                  icon: Icons.videocam_outlined,
                  title: 'ATTENDANCE',
                  value: '${attendance.round()}% present',
                  percent: attendance,
                  color: const Color(0xFFFFC82E),
                  onTap: onAttendance,
                ),
              ],
            );
          }
          return Row(children: [
            Expanded(
              child: _ReferenceMetric(
                theme: theme,
                icon: Icons.school_rounded,
                title: 'COURSE PROGRESS',
                value: '${progress.round()}% completed',
                percent: progress,
                color: const Color(0xFF9652FF),
                onTap: onCourses,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ReferenceMetric(
                theme: theme,
                icon: Icons.videocam_outlined,
                title: 'ATTENDANCE',
                value: '${attendance.round()}% present',
                percent: attendance,
                color: const Color(0xFFFFC82E),
                onTap: onAttendance,
              ),
            ),
          ]);
        },
      );
}

class _ReferenceMetric extends StatelessWidget {
  final dynamic theme;
  final IconData icon;
  final String title;
  final String value;
  final double percent;
  final Color color;
  final VoidCallback onTap;
  const _ReferenceMetric({
    required this.theme,
    required this.icon,
    required this.title,
    required this.value,
    required this.percent,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => _ReferenceCard(
        theme: theme,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 240;
            if (isCompact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _ReferenceIcon(icon: icon, color: color, size: 38),
                      RingProgress(
                        percent: percent,
                        color: color,
                        track: Colors.white24,
                        textColor: Colors.white,
                        size: 40,
                        strokeWidth: 4,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(.70),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              );
            }

            return Row(
              children: [
                _ReferenceIcon(icon: icon, color: color, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(.70),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                RingProgress(
                  percent: percent,
                  color: color,
                  track: Colors.white24,
                  textColor: Colors.white,
                  size: 46,
                  strokeWidth: 5,
                ),
              ],
            );
          },
        ),
      );
}

class _ReferenceIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const _ReferenceIcon({required this.icon, required this.color, this.size = 42});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color.withOpacity(.95), borderRadius: BorderRadius.circular(13), boxShadow: [BoxShadow(color: color.withOpacity(.48), blurRadius: 14)]),
        child: Icon(icon, color: Colors.white, size: size * .48),
      );
}

class _ReferenceFilterBar extends StatefulWidget {
  final dynamic theme;
  final DateTimeRange? selectedDateRange;
  final ValueChanged<DateTimeRange?>? onDateRangeChanged;

  const _ReferenceFilterBar({
    super.key,
    required this.theme,
    this.selectedDateRange,
    this.onDateRangeChanged,
  });

  @override
  State<_ReferenceFilterBar> createState() => _ReferenceFilterBarState();
}

class _ReferenceFilterBarState extends State<_ReferenceFilterBar> {
  DateTimeRange? _selectedRange;

  @override
  void initState() {
    super.initState();
    _selectedRange = widget.selectedDateRange;
  }

  @override
  void didUpdateWidget(covariant _ReferenceFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDateRange != oldWidget.selectedDateRange) {
      _selectedRange = widget.selectedDateRange;
    }
  }

  String _formatRange(DateTimeRange range) {
    return '${range.start.day} ${_monthShort(range.start.month)} — ${range.end.day} ${_monthShort(range.end.month)}, ${range.end.year}';
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final now = DateTime.now();
    final initial = _selectedRange ??
        DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: now,
        );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2022),
      lastDate: DateTime(now.year + 2),
      initialDateRange: initial,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF071D43),
            dialogBackgroundColor: const Color(0xFF0A2558),
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF27D9D3),
              onPrimary: Color(0xFF041838),
              surface: Color(0xFF0C2B64),
              onSurface: Colors.white,
              surfaceContainerHighest: Color(0xFF104476),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF071D43),
              foregroundColor: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _selectedRange = picked);
      widget.onDateRangeChanged?.call(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasCustomRange = _selectedRange != null;
    final rangeText = hasCustomRange
        ? _formatRange(_selectedRange!)
        : _currentDateRange();

    return _ReferenceCard(
      theme: widget.theme,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(children: [
          _ReferencePill(
            icon: Icons.calendar_month_outlined,
            label: rangeText,
            isActive: hasCustomRange,
            onTap: () => _pickDateRange(context),
            onClear: hasCustomRange
                ? () {
                    setState(() => _selectedRange = null);
                    widget.onDateRangeChanged?.call(null);
                  }
                : null,
          ),
          const SizedBox(width: 8),
          _ReferencePill(
            icon: Icons.tune_rounded,
            label: 'Filters',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Filter options active')),
              );
            },
          ),
          const SizedBox(width: 8),
          _ReferencePill(
            icon: Icons.download_outlined,
            label: 'Export',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Exporting report...')),
              );
            },
          ),
        ]),
      ),
    );
  }
}

String _currentDateRange() {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, 1);
  return '${start.day} ${_monthShort(start.month)} — ${now.day} ${_monthShort(now.month)}, ${now.year}';
}

String _monthShort(int month) => const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][month - 1];

class _ReferencePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  const _ReferencePill({
    required this.icon,
    required this.label,
    this.isActive = false,
    this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF27D9D3).withOpacity(.16)
                  : Colors.white.withOpacity(.08),
              border: Border.all(
                color: isActive
                    ? const Color(0xFF27D9D3).withOpacity(.50)
                    : Colors.white.withOpacity(.13),
              ),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                icon,
                color: isActive ? const Color(0xFF27D9D3) : Colors.white,
                size: 16,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? const Color(0xFF27D9D3) : Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (onClear != null) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onClear,
                  child: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF27D9D3),
                    size: 14,
                  ),
                ),
              ],
            ]),
          ),
        ),
      );
}

class _ReferenceAnalyticsGrid extends StatelessWidget {
  final dynamic theme;
  final bool wide;
  final double progress;
  final double attendance;
  final double performance;
  final List<double> trend;
  final List<MentorModel> mentors;
  final DateTimeRange? selectedDateRange;

  const _ReferenceAnalyticsGrid({
    required this.theme,
    required this.wide,
    required this.progress,
    required this.attendance,
    required this.performance,
    required this.trend,
    required this.mentors,
    this.selectedDateRange,
  });

  @override
  Widget build(BuildContext context) {
    final time = _ReferenceCard(
      theme: theme,
      child: _ReferenceTimeChart(
        theme: theme,
        trend: trend,
        performance: performance,
        selectedDateRange: selectedDateRange,
      ),
    );
    final progressCard = _ReferenceCard(
      theme: theme,
      child: _ReferenceProgressChart(
        theme: theme,
        progress: progress,
        attendance: attendance,
        performance: performance,
      ),
    );
    final mentorsCard = _ReferenceCard(
      theme: theme,
      child: _ReferenceMentors(mentors: mentors),
    );
    if (!wide) {
      return Column(children: [
        time,
        const SizedBox(height: 10),
        progressCard,
        const SizedBox(height: 10),
        mentorsCard,
      ]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 4, child: time),
        const SizedBox(width: 10),
        Expanded(flex: 3, child: progressCard),
        const SizedBox(width: 10),
        Expanded(flex: 3, child: mentorsCard),
      ],
    );
  }
}

class _ReferenceTimeChart extends StatefulWidget {
  final dynamic theme;
  final List<double> trend;
  final double performance;
  final DateTimeRange? selectedDateRange;

  const _ReferenceTimeChart({
    super.key,
    required this.theme,
    required this.trend,
    required this.performance,
    this.selectedDateRange,
  });

  @override
  State<_ReferenceTimeChart> createState() => _ReferenceTimeChartState();
}

class _ReferenceTimeChartState extends State<_ReferenceTimeChart> {
  String _interval = 'Month';
  DateTimeRange? _activeRange;

  @override
  void initState() {
    super.initState();
    _activeRange = widget.selectedDateRange;
    _syncIntervalForRange();
  }

  @override
  void didUpdateWidget(covariant _ReferenceTimeChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDateRange != oldWidget.selectedDateRange) {
      _activeRange = widget.selectedDateRange;
      _syncIntervalForRange();
    }
  }

  void _syncIntervalForRange() {
    if (_activeRange != null) {
      final days = _activeRange!.duration.inDays + 1;
      if (days <= 10) {
        _interval = 'Day';
      } else if (days <= 45) {
        _interval = 'Week';
      } else {
        _interval = 'Month';
      }
    }
  }

  List<double> _getValuesForInterval() {
    final baseTrend = widget.trend.isNotEmpty
        ? widget.trend
        : [0.35, 0.45, 0.52, 0.48, 0.62, 0.70, 0.78];
    final currentLevel = (widget.performance / 100).clamp(0.1, 1.0);

    if (_activeRange != null) {
      final days = _activeRange!.duration.inDays + 1;
      if (_interval == 'Day') {
        final count = days.clamp(1, 14);
        return List.generate(count, (i) {
          final date = _activeRange!.start.add(Duration(days: i));
          final seed = (date.day * 17 + date.month * 11) % 100;
          final factor = 0.65 + (seed / 100.0) * 0.35;
          return (currentLevel * factor).clamp(0.05, 1.0);
        });
      } else if (_interval == 'Week') {
        final count = (days / 7).ceil().clamp(2, 6);
        return List.generate(count, (i) {
          final seed = (i * 23 + _activeRange!.start.month * 13) % 100;
          final factor = 0.70 + (seed / 100.0) * 0.30;
          return (currentLevel * factor).clamp(0.05, 1.0);
        });
      } else {
        final monthsCount = ((_activeRange!.end.year - _activeRange!.start.year) * 12 +
                _activeRange!.end.month -
                _activeRange!.start.month +
                1)
            .clamp(1, 12);
        return List.generate(monthsCount, (i) {
          final m = (_activeRange!.start.month + i - 1) % 12;
          final factor = 0.60 + ((m * 17) % 40) / 100.0;
          return (currentLevel * factor).clamp(0.05, 1.0);
        });
      }
    }

    if (_interval == 'Day') {
      if (baseTrend.length >= 7) {
        return baseTrend.sublist(baseTrend.length - 7);
      }
      return [
        (currentLevel * 0.65).clamp(0.05, 1.0),
        (currentLevel * 0.85).clamp(0.05, 1.0),
        (currentLevel * 0.75).clamp(0.05, 1.0),
        (currentLevel * 0.95).clamp(0.05, 1.0),
        (currentLevel * 0.70).clamp(0.05, 1.0),
        (currentLevel * 0.50).clamp(0.05, 1.0),
        currentLevel.clamp(0.05, 1.0),
      ];
    } else if (_interval == 'Week') {
      if (baseTrend.length >= 4) {
        return baseTrend.sublist(baseTrend.length - 4);
      }
      return [
        (currentLevel * 0.60).clamp(0.05, 1.0),
        (currentLevel * 0.75).clamp(0.05, 1.0),
        (currentLevel * 0.88).clamp(0.05, 1.0),
        currentLevel.clamp(0.05, 1.0),
      ];
    } else {
      return baseTrend;
    }
  }

  List<String> _getLabelsForInterval() {
    if (_activeRange != null) {
      final days = _activeRange!.duration.inDays + 1;
      if (_interval == 'Day') {
        final count = days.clamp(1, 14);
        return List.generate(count, (i) {
          final date = _activeRange!.start.add(Duration(days: i));
          return '${date.day} ${_monthShort(date.month)}';
        });
      } else if (_interval == 'Week') {
        final count = (days / 7).ceil().clamp(2, 6);
        return List.generate(count, (i) => 'Wk ${i + 1}');
      } else {
        const allMonths = [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
        ];
        final monthsCount = ((_activeRange!.end.year - _activeRange!.start.year) * 12 +
                _activeRange!.end.month -
                _activeRange!.start.month +
                1)
            .clamp(1, 12);
        return List.generate(monthsCount, (i) {
          final m = (_activeRange!.start.month - 1 + i) % 12;
          return allMonths[m];
        });
      }
    }

    if (_interval == 'Day') {
      return const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    } else if (_interval == 'Week') {
      return const ['Week 1', 'Week 2', 'Week 3', 'Week 4'];
    } else {
      const allMonths = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final count = _getValuesForInterval().length.clamp(1, 12);
      final currentMonth = DateTime.now().month;
      final start = (currentMonth - count + 12) % 12;
      return List.generate(count, (i) => allMonths[(start + i) % 12]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final values = _getValuesForInterval();
    final peak = (values.isEmpty ? 0.0 : values.reduce(math.max)) * 100;
    final labels = _getLabelsForInterval();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _ReferenceTitle(
        title: 'Time Spending',
        trailingWidget: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_activeRange != null) ...[
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF27D9D3).withOpacity(.18),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: const Color(0xFF27D9D3).withOpacity(.4)),
                ),
                child: const Text(
                  'FILTERED',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF27D9D3),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.12),
                border: Border.all(color: Colors.white24),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _interval,
                  dropdownColor: const Color(0xFF0A2558),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: Colors.white, size: 16),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  isDense: true,
                  items: const [
                    DropdownMenuItem(value: 'Day', child: Text('Day')),
                    DropdownMenuItem(value: 'Week', child: Text('Week')),
                    DropdownMenuItem(value: 'Month', child: Text('Month')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _interval = val);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      if (values.isEmpty)
        SizedBox(
          height: 120,
          child: Center(
            child: Text(
              'No performance trend data',
              style: TextStyle(
                  color: Colors.white.withOpacity(.65), fontSize: 11),
            ),
          ),
        )
      else
        Stack(
          children: [
            MiniLineChart(
              values: values,
              lineColor: const Color(0xFF9E5CFF),
              fillColor: const Color(0xFF713BDB),
              height: 120,
            ),
            if (values.isNotEmpty)
              Positioned(
                top: 4,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF27D9D3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${peak.round()}%',
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF041838),
                    ),
                  ),
                ),
              ),
          ],
        ),
      const SizedBox(height: 6),
      Row(
        children: labels
            .map((l) => Expanded(
                  child: Center(
                    child: Text(
                      l,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(.55),
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: Text(
              'Overall performance: ${widget.performance.round()}%',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: Colors.white.withOpacity(.75), fontSize: 11),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _activeRange != null
                ? 'Filtered (${_interval == 'Day' ? 'Daily' : _interval == 'Week' ? 'Weekly' : 'Monthly'})'
                : _interval == 'Day'
                    ? 'Daily Trend'
                    : _interval == 'Week'
                        ? 'Weekly Trend'
                        : 'Monthly Trend',
            style: TextStyle(
              color: const Color(0xFF27D9D3).withOpacity(.85),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ]);
  }
}

class _ReferenceProgressChart extends StatelessWidget {
  final dynamic theme;
  final double progress;
  final double attendance;
  final double performance;
  const _ReferenceProgressChart({required this.theme, required this.progress, required this.attendance, required this.performance});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _ReferenceTitle(title: 'Your Progress'),
        Text('Your total course progress here', style: TextStyle(color: Colors.white.withOpacity(.65), fontSize: 11)),
        const SizedBox(height: 10),
        Center(child: DonutChart(size: 132, strokeWidth: 17, track: Colors.white12, segments: [(progress.clamp(1, 100), const Color(0xFF9B5CFF)), (attendance.clamp(1, 100), const Color(0xFF27D9D3)), (performance.clamp(1, 100), const Color(0xFFFFCF35))], center: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('Total', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Text('Achievement', style: TextStyle(color: Colors.white70, fontSize: 10))]))),
        const SizedBox(height: 9),
        _ReferenceLegend(color: const Color(0xFF9B5CFF), label: 'Course Progress', value: '${progress.round()}%'),
        _ReferenceLegend(color: const Color(0xFF27D9D3), label: 'Attendance', value: '${attendance.round()}%'),
        _ReferenceLegend(color: const Color(0xFFFFCF35), label: 'Performance', value: '${performance.round()}%'),
      ]);
}

/// One mentor row: avatar, name, what they teach/mentor and a role chip. Shared
/// by both the "Mentor" (batch) and "Faculty" (course instructors) sections so
/// the two lists read identically.
class _MentorRow extends StatelessWidget {
  final MentorModel mentor;
  final bool primary;
  const _MentorRow({required this.mentor, required this.primary});

  @override
  Widget build(BuildContext context) {
    final accent = primary ? const Color(0xFF9B5CFF) : const Color(0xFF35D9C6);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.07),
          border: Border.all(color: Colors.white24),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          _ReferenceIcon(
              icon: primary ? Icons.school_outlined : Icons.person_outline,
              color: accent,
              size: 36),
          const SizedBox(width: 9),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(mentor.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              Text(mentor.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 9)),
            ]),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: accent.withOpacity(.16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(primary ? 'MENTOR' : 'FACULTY',
                style: TextStyle(color: accent, fontSize: 7.5, fontWeight: FontWeight.w800, letterSpacing: .4)),
          ),
        ]),
      ),
    );
  }
}

/// Small uppercased section heading inside the Mentors card ("MENTOR", "FACULTY").
class _MentorSectionHeading extends StatelessWidget {
  final String text;
  final IconData icon;
  final int count;
  const _MentorSectionHeading({required this.text, required this.icon, required this.count});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, color: Colors.white.withOpacity(.7), size: 12),
        const SizedBox(width: 5),
        Text(text.toUpperCase(),
            style: TextStyle(
                color: Colors.white.withOpacity(.7),
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0)),
        const SizedBox(width: 5),
        Text('($count)',
            style: TextStyle(
                color: Colors.white.withOpacity(.45),
                fontSize: 9,
                fontWeight: FontWeight.w600)),
      ]);
}

/// Placeholder shown when a section has no member (no batch mentor configured,
/// or none of the student's courses have a faculty assigned).
class _MentorEmptyRow extends StatelessWidget {
  final String text;
  const _MentorEmptyRow({required this.text});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.05),
          border: Border.all(color: Colors.white12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white54, fontSize: 9.5)),
      );
}

/// The dashboard "Mentors" card, split into the two real relationships the
/// platform holds for a student:
///  * "Mentor"  — the faculty assigned to the student's own batch (their cohort
///                mentor, i.e. {@code batches.mentor_id}); and
///  * "Faculty" — every instructor of the courses the student is eligible for
///                (enrollments + their plan's courses).
/// Both render with the same row treatment.
class _ReferenceMentors extends StatelessWidget {
  final List<MentorModel> mentors;
  const _ReferenceMentors({required this.mentors});

  @override
  Widget build(BuildContext context) {
    final batchMentor = mentors.where((m) => m.primaryMentor).toList();
    final faculty = mentors.where((m) => !m.primaryMentor).toList();

    if (mentors.isEmpty) {
      // Genuinely no mentor configured: no batch mentor on the cohort and no
      // instructor on any of the student's courses.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ReferenceTitle(title: 'Mentors', trailing: 'Live'),
          const SizedBox(height: 18),
          Center(
            child: Column(children: [
              Icon(Icons.groups_outlined, color: Colors.white.withOpacity(.55), size: 34),
              const SizedBox(height: 8),
              const Text('No mentor data available', style: TextStyle(color: Colors.white70, fontSize: 11)),
              const SizedBox(height: 4),
              Text('No batch mentor or course faculty is configured for this student.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(.48), fontSize: 9)),
            ]),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ReferenceTitle(title: 'Mentors', trailing: 'Live'),
        const SizedBox(height: 10),

        // ---- Mentor: the faculty of the student's own batch ----
        _MentorSectionHeading(text: 'Mentor', icon: Icons.school_outlined, count: batchMentor.length),
        const SizedBox(height: 6),
        if (batchMentor.isEmpty)
          const _MentorEmptyRow(text: 'No faculty is assigned to this batch yet.')
        else
          ...batchMentor.map((m) => _MentorRow(mentor: m, primary: true)),

        const SizedBox(height: 8),

        // ---- Faculty: instructors of the courses the student is eligible for ----
        _MentorSectionHeading(text: 'Faculty', icon: Icons.groups_outlined, count: faculty.length),
        const SizedBox(height: 6),
        if (faculty.isEmpty)
          const _MentorEmptyRow(text: 'No faculty is assigned to this student\'s courses yet.')
        else
          ...faculty.map((m) => _MentorRow(mentor: m, primary: false)),
      ],
    );
  }
}

class _ReferenceCourseRow extends StatelessWidget {
  final dynamic theme;
  final List courses;
  const _ReferenceCourseRow({required this.theme, required this.courses});
  @override
  Widget build(BuildContext context) {
    if (courses.isEmpty) {
      return _ReferenceCard(theme: theme, child: const Text('No courses assigned yet', style: TextStyle(color: Colors.white70, fontSize: 12)));
    }
    final visible = courses.take(2).toList();
    return Row(children: List.generate(visible.length, (index) {
      final course = visible[index];
      final percent = course.progressPercent as int;
      return Expanded(child: Padding(
        padding: EdgeInsets.only(right: index == visible.length - 1 ? 0 : 10),
        child: _ReferenceCourseCard(theme: theme, title: course.title, watched: '${course.completedLessons}/${course.totalLessons} Lessons Watched', percent: percent, color: index.isEven ? const Color(0xFF9B5CFF) : const Color(0xFFFFC82E), icon: index.isEven ? Icons.menu_book_outlined : Icons.play_lesson_outlined, caption: course.instructorName),
      ));
    }));
  }
}

class _ReferenceCourseCard extends StatelessWidget {
  final dynamic theme; final String title; final String watched; final int percent; final Color color; final IconData icon;

  /// Real caption above the title (the course's instructor); falls back to
  /// 'COURSE' rather than a hardcoded category when the course has no instructor.
  final String caption;

  const _ReferenceCourseCard({required this.theme, required this.title, required this.watched, required this.percent, required this.color, required this.icon, this.caption = ''});
  @override
  Widget build(BuildContext context) {
    return _ReferenceCard(
      theme: theme,
      padding: const EdgeInsets.all(10),
      child: Row(children: [
        _ReferenceIcon(icon: icon, color: color, size: 40),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(caption.isEmpty ? 'COURSE' : caption.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(.6), fontSize: 8)),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              Text(watched, style: const TextStyle(color: Colors.white70, fontSize: 9)),
            ],
          ),
        ),
        RingProgress(percent: percent.toDouble(), color: color, track: Colors.white24, textColor: Colors.white, size: 40, strokeWidth: 5),
      ]),
    );
  }
}

class _ReferenceScheduleCard extends StatelessWidget {
  final dynamic theme;
  final List events;
  const _ReferenceScheduleCard({required this.theme, required this.events});
  @override
  Widget build(BuildContext context) {
    // Already "the next two events" from /dashboard/student/{id}/upcoming-events,
    // soonest first, so no client-side filtering or re-sorting is needed.
    final upcoming = events.take(2).toList();
    return _ReferenceCard(theme: theme, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _ReferenceTitle(title: 'Upcoming Events', trailing: 'Live'),
      const SizedBox(height: 8),
      if (upcoming.isEmpty) const Text('No upcoming events', style: TextStyle(color: Colors.white70, fontSize: 12))
      else ...upcoming.map((event) => _ReferenceScheduleItem(color: const Color(0xFF35D9C6), title: event.title, date: event.date, time: event.time.isEmpty ? 'All day' : event.time)),
    ]));
  }
}

class _ReferenceScheduleItem extends StatelessWidget {
  final Color color; final String title; final String date; final String time;
  const _ReferenceScheduleItem({required this.color, required this.title, required this.date, required this.time});
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 7), padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: Colors.white.withOpacity(.07), border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(14)), child: Row(children: [_ReferenceIcon(icon: Icons.desktop_windows_outlined, color: color, size: 40), const SizedBox(width: 10), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)), Text('▣ $date', style: const TextStyle(color: Colors.white70, fontSize: 9)), Text('◷ $time', style: const TextStyle(color: Colors.white70, fontSize: 9))]) ]));
}

class _ReferenceLowerGrid extends StatelessWidget {
  final dynamic theme; final bool wide; final Map<String, dynamic> attendanceHistory; final Map<String, dynamic> placementOverview; final int interviewCount;
  const _ReferenceLowerGrid({required this.theme, required this.wide, required this.attendanceHistory, required this.placementOverview, required this.interviewCount});
  @override
  Widget build(BuildContext context) { final attendance = _ReferenceCard(theme: theme, child: _ReferenceAttendance(history: attendanceHistory)); final hiring = _ReferenceCard(theme: theme, child: _ReferenceHiring(overview: placementOverview, interviewCount: interviewCount)); if (!wide) return Column(children: [attendance, const SizedBox(height: 10), hiring]); return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: attendance), const SizedBox(width: 10), Expanded(child: hiring)]); }
}

/// Resolves the class date for an attendance history entry. The backend's
/// `/attendance/student/{id}` payload exposes the class date under `startTime`
/// (the event's start time); `date`/`at`/`markedAt` remain as fallbacks so the
/// parser stays tolerant of alternate payload shapes.
DateTime? _attendanceRecordDate(Map item) {
  final raw = item['startTime'] ?? item['date'] ?? item['at'] ?? item['markedAt'];
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  return DateTime.tryParse(raw.toString());
}

/// Colour-keyed statistic used in the attendance card's comparison header.
class _AttendanceStat extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  const _AttendanceStat(
      {required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 9.5)),
        const SizedBox(width: 3),
        Text(value,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
      ]);
}

/// "Attendance" panel. Plots, per month, the number of classes held (total,
/// muted) beside the number the student actually attended (bright) — so the bar
/// heights vary with the real counts instead of every month reading the same.
/// A comparison header shows the year's total vs attended classes and the rate.
class _ReferenceAttendance extends StatelessWidget {
  final Map<String, dynamic> history;
  const _ReferenceAttendance({required this.history});

  /// Per-month (total classes, attended classes) for [year], derived from the
  /// real marked records. Months without any marked class are omitted.
  Map<int, (int, int)> _monthlyCounts(int year) {
    final raw = history['history'];
    if (raw is! List) return const {};
    final totals = <int, int>{};
    final presents = <int, int>{};
    for (final item in raw.whereType<Map>()) {
      final date = _attendanceRecordDate(item);
      if (date == null || date.year != year) continue;
      totals[date.month] = (totals[date.month] ?? 0) + 1;
      if (item['present'] == true || item['isPresent'] == true) {
        presents[date.month] = (presents[date.month] ?? 0) + 1;
      }
    }
    return {
      for (final entry in totals.entries)
        entry.key: (entry.value, presents[entry.key] ?? 0),
    };
  }

  /// The year the chart represents: the most recent year in which the student
  /// had a marked class, falling back to the current year when there is no data.
  int _chartYear() {
    final raw = history['history'];
    if (raw is List) {
      int? latest;
      for (final item in raw.whereType<Map>()) {
        final date = _attendanceRecordDate(item);
        if (date == null) continue;
        if (latest == null || date.year > latest) latest = date.year;
      }
      if (latest != null) return latest;
    }
    return DateTime.now().year;
  }

  @override
  Widget build(BuildContext context) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const totalColor = Color(0xFF3A63A8);
    const attendedColor = Color(0xFF9B5CFF);
    const currentColor = Color(0xFFFFD43B);

    final year = _chartYear();
    final counts = _monthlyCounts(year);
    final now = DateTime.now();
    // Scale every bar against the busiest month so the month-to-month difference
    // is the real count difference (e.g. 2 vs 3 vs 7 classes), never a flat line.
    final maxCount = counts.values.fold<int>(1, (m, c) => math.max(m, c.$1));
    final totalAll = counts.values.fold<int>(0, (s, c) => s + c.$1);
    final attendedAll = counts.values.fold<int>(0, (s, c) => s + c.$2);
    final rate = totalAll > 0 ? (attendedAll * 100 / totalAll).round() : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ReferenceTitle(title: 'Attendance', trailing: '$year'),
        const SizedBox(height: 10),
        Row(children: [
          _AttendanceStat(color: totalColor, label: 'Total', value: '$totalAll'),
          const SizedBox(width: 14),
          _AttendanceStat(color: attendedColor, label: 'Attended', value: '$attendedAll'),
          const Spacer(),
          Text('$rate%',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          height: 128,
          child: LayoutBuilder(builder: (context, constraints) {
            const labelHeight = 13.0;
            final barArea = (constraints.maxHeight - labelHeight).clamp(24.0, 200.0).toDouble();
            double barHeight(int value) =>
                value <= 0 ? 2.0 : ((value / maxCount) * barArea).clamp(3.0, barArea).toDouble();
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(12, (i) {
                final month = i + 1;
                final entry = counts[month];
                final total = entry?.$1 ?? 0;
                final attended = entry?.$2 ?? 0;
                final isCurrent = now.year == year && now.month == month;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(
                          height: barArea,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Total classes held this month.
                              Expanded(
                                child: Container(
                                  height: barHeight(total),
                                  decoration: BoxDecoration(
                                    color: totalColor.withOpacity(total == 0 ? 0.25 : 0.85),
                                    borderRadius:
                                        const BorderRadius.vertical(top: Radius.circular(3)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 1.5),
                              // Classes actually attended this month.
                              Expanded(
                                child: Container(
                                  height: barHeight(attended),
                                  decoration: BoxDecoration(
                                    color: isCurrent
                                        ? currentColor
                                        : attendedColor.withOpacity(attended == 0 ? 0.25 : 1.0),
                                    borderRadius:
                                        const BorderRadius.vertical(top: Radius.circular(3)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(months[i], style: const TextStyle(color: Colors.white70, fontSize: 7)),
                      ],
                    ),
                  ),
                );
              }),
            );
          }),
        ),
      ],
    );
  }
}

class _ReferenceHiring extends StatelessWidget {
  final Map<String, dynamic> overview;
  final int interviewCount;
  const _ReferenceHiring({required this.overview, required this.interviewCount});
  @override
  Widget build(BuildContext context) {
    final open = (overview['openCount'] as num?)?.toInt() ?? 0;
    final applications = (overview['appliedCount'] as num?)?.toInt() ?? 0;
    final offers = (overview['selectedCount'] as num?)?.toInt() ?? 0;
    final items = [('Open Roles', '$open'), ('Applications', '$applications'), ('Interviews', '$interviewCount'), ('Offers', '$offers')];
    final totalPosted = (overview['totalPosted'] as num?)?.toInt() ?? 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _ReferenceTitle(title: 'Hiring Dashboard', trailing: 'Live'),
      const SizedBox(height: 8),
      Row(children: [for (final item in items) Expanded(child: Padding(padding: const EdgeInsets.only(right: 5), child: Container(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 3), decoration: BoxDecoration(color: Colors.white.withOpacity(.07), borderRadius: BorderRadius.circular(11)), child: Column(children: [const Icon(Icons.work_outline, color: Color(0xFF35DAD8), size: 18), Text(item.$2, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), Text(item.$1, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 7))]))))]),
      const SizedBox(height: 11),
      Text('Published drives: $totalPosted', style: const TextStyle(color: Colors.white70, fontSize: 10)),
      const SizedBox(height: 8),
      Text('Pipeline: Applied $applications • Interviews $interviewCount • Offers $offers', style: const TextStyle(color: Colors.white70, fontSize: 8)),
    ]);
  }
}

class _ReferenceQuickActions extends StatelessWidget {
  final dynamic theme; final bool wide;
  const _ReferenceQuickActions({required this.theme, required this.wide});
  @override
  Widget build(BuildContext context) {
    final actions = [
      ('Open Roles', Icons.work_outline, AppRoutes.placementDrives),
      ('Applications', Icons.description_outlined, AppRoutes.assignments),
      ('Interviews', Icons.calendar_month_outlined, AppRoutes.calendar),
      ('Offers', Icons.track_changes, AppRoutes.placementDrives),
      ('Courses', Icons.menu_book_outlined, AppRoutes.courses),
      ('Progress', Icons.analytics_outlined, AppRoutes.home),
      ('Mentors', Icons.groups_outlined, AppRoutes.qa),
      ('Schedule', Icons.calendar_today_outlined, AppRoutes.calendar),
    ];
    const iconColors = [Color(0xFF23D5D2), Color(0xFFFF8A54), Color(0xFFA66AFF), Color(0xFF25D29D)];
    return _ReferenceCard(
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ReferenceTitle(title: 'Quick Actions'),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: actions.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: wide ? 8 : 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: .9,
            ),
            itemBuilder: (context, i) {
              return InkWell(
                onTap: () => context.go(actions[i].$3),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.07),
                    border: Border.all(color: Colors.white24),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(actions[i].$2, color: iconColors[i % 4], size: 24),
                      const SizedBox(height: 5),
                      Text(
                        actions[i].$1,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ReferenceCard extends StatelessWidget {
  final dynamic theme; final Widget child; final EdgeInsetsGeometry padding; final VoidCallback? onTap;
  const _ReferenceCard({required this.theme, required this.child, this.padding = const EdgeInsets.all(12), this.onTap});
  @override
  Widget build(BuildContext context) { final card = ClipRRect(borderRadius: BorderRadius.circular(17), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12), child: Container(padding: padding, decoration: BoxDecoration(color: const Color(0xFF173C70).withOpacity(.72), border: Border.all(color: Colors.white.withOpacity(.22)), borderRadius: BorderRadius.circular(17), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.18), blurRadius: 14)]), child: child))); return onTap == null ? card : InkWell(onTap: onTap, borderRadius: BorderRadius.circular(17), child: card); }
}

class _ReferenceTitle extends StatelessWidget {
  final String title;
  final String? trailing;
  final Widget? trailingWidget;
  const _ReferenceTitle({required this.title, this.trailing, this.trailingWidget});
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700))),
        if (trailingWidget != null)
          trailingWidget!
        else if (trailing != null)
          Text(trailing!,
              style: TextStyle(
                  color: Colors.white.withOpacity(.8),
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
      ]);
}

class _ReferenceLegend extends StatelessWidget {
  final Color color; final String label; final String value;
  const _ReferenceLegend({required this.color, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 5), child: Row(children: [Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 7), Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10))), Text(value, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))]));
}


class _AssessmentPerformanceRow extends StatelessWidget {
  final dynamic theme;
  final List assignments;
  final List exams;
  const _AssessmentPerformanceRow({required this.theme, required this.assignments, required this.exams});

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: _PerformanceTile(theme: theme, title: 'Assignments', icon: Icons.assignment_outlined, items: assignments, submitted: (item) => item.submissionId != null || item.status?.toString().toLowerCase() == 'submitted', score: (item) => item.marksObtained, total: (item) => item.totalMarks, color: theme.accent)),
        const SizedBox(width: 10),
        Expanded(child: _PerformanceTile(theme: theme, title: 'Exams', icon: Icons.quiz_outlined, items: exams, submitted: (item) => item.submissionId != null || item.status?.toString().toLowerCase() == 'submitted', score: (item) => item.marksObtained, total: (item) => item.totalMarks, color: theme.info)),
      ]);
}

class _PerformanceTile extends StatelessWidget {
  final dynamic theme;
  final String title;
  final IconData icon;
  final List items;
  final bool Function(dynamic) submitted;
  final int? Function(dynamic) score;
  final int? Function(dynamic) total;
  final Color color;
  const _PerformanceTile({required this.theme, required this.title, required this.icon, required this.items, required this.submitted, required this.score, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    final submittedCount = items.where(submitted).length;
    final totalCount = items.length;
    final scores = items.map(score).whereType<num>().fold<double>(0, (sum, value) => sum + value);
    final marks = items.map(total).whereType<num>().fold<double>(0, (sum, value) => sum + value);
    final percentage = marks == 0 ? 0.0 : (scores * 100 / marks).clamp(0.0, 100.0);
    final pending = (totalCount - submittedCount).clamp(0, totalCount);
    return _ReferenceCard(theme: theme, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Container(width: 32, height: 32, decoration: BoxDecoration(color: color.withOpacity(.2), shape: BoxShape.circle), child: Icon(icon, color: color, size: 18)), const SizedBox(width: 8), Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800))), Text('${percentage.round()}%', style: TextStyle(color: color, fontSize: 19, fontWeight: FontWeight.w900))]),
      const SizedBox(height: 8),
      Row(children: [Expanded(child: Text('Submitted $submittedCount/$totalCount', style: const TextStyle(color: Colors.white70, fontSize: 9))), Text('${scores.round()}/${marks.round()} marks', style: const TextStyle(color: Colors.white70, fontSize: 9))]),
      const SizedBox(height: 9),
      Row(children: [DonutChart(size: 55, strokeWidth: 8, track: Colors.white12, segments: [(submittedCount.toDouble(), color), (pending.toDouble(), Colors.white24)]), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_PerformanceLegend(color: color, label: 'Submitted', value: '$submittedCount'), _PerformanceLegend(color: Colors.white38, label: 'Pending', value: '$pending')]))]),
    ]));
  }
}

class _PerformanceLegend extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  const _PerformanceLegend({required this.color, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 3), child: Row(children: [Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 5), Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 9))), Text(value, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))]));
}
