import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/widgets/common_header.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  int _dailyYear = DateTime.now().year;
  DateTime _dailyMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  int _eventYear = DateTime.now().year;
  DateTime _eventMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  static const _bgDark = Color(0xFF071D43);
  static const _cardDark = Color(0xFF0C2B64);
  static const _cyan = Color(0xFF27D9D3);
  static const _purple = Color(0xFF9B5CFF);
  static const _green = Color(0xFF10B981);
  static const _red = Color(0xFFEF4444);

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  static const _fullMonthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  static const _weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  bool _isDaily(Map<String, dynamic> r) {
    final type = r['eventType']?.toString().toUpperCase() ?? '';
    final title = r['eventTitle']?.toString().toLowerCase() ?? '';
    return type == 'DAILY_ATTENDANCE' ||
        type == 'DAILY' ||
        title.contains('daily attendance') ||
        type == 'CLASS';
  }

  DateTime? _dateOf(Map<String, dynamic> r) {
    final start = r['startTime']?.toString();
    if (start == null) return null;
    return DateTime.tryParse(start)?.toLocal();
  }

  void _showDayDetailsModal(
    BuildContext context, {
    required DateTime date,
    required List<Map<String, dynamic>> recordsForDay,
    required String category,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF092350),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final formattedDate =
            '${date.day} ${_fullMonthNames[date.month - 1]} ${date.year}';

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      formattedDate,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _cyan.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      category,
                      style: const TextStyle(
                        color: _cyan,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white12, height: 24),
              if (recordsForDay.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Center(
                    child: Text(
                      'No attendance session recorded for this day.',
                      style: TextStyle(color: Colors.white60, fontSize: 13.5),
                    ),
                  ),
                )
              else
                ...recordsForDay.map((record) {
                  final present = record['present'] == true;
                  final title =
                      record['eventTitle']?.toString() ?? 'Attendance Session';
                  final subject = record['subject']?.toString();
                  final remarks = record['remarks']?.toString();
                  final time = record['startTime']?.toString() ?? '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _cardDark.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: present
                            ? _green.withOpacity(0.4)
                            : _red.withOpacity(0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: present
                                ? _green.withOpacity(0.2)
                                : _red.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            present
                                ? Icons.check_circle_rounded
                                : Icons.cancel_rounded,
                            color: present ? _green : _red,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              if (subject != null && subject.isNotEmpty)
                                Text(
                                  'Subject: $subject',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12),
                                ),
                              if (time.length >= 16)
                                Text(
                                  'Time: ${time.substring(11, 16)}',
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 11),
                                ),
                              if (remarks != null && remarks.isNotEmpty)
                                Text(
                                  'Remarks: $remarks',
                                  style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: present
                                ? _green.withOpacity(0.25)
                                : _red.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            present ? 'Present' : 'Absent',
                            style: TextStyle(
                              color: present ? _green : _red,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final attendanceAsync = ref.watch(attendanceHistoryProvider);

    return CommonHeaderScaffold(
      subtitle: 'Attendance',
      backgroundColor: _bgDark,
      body: attendanceAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: _cyan),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.white38),
              const SizedBox(height: 12),
              const Text('Failed to load attendance records',
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(attendanceHistoryProvider),
                child: const Text('Retry', style: TextStyle(color: _cyan)),
              ),
            ],
          ),
        ),
        data: (attendanceData) {
          final allHistory = (attendanceData['history'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>()
              .toList();

          // Split records into 2 categories: Daily Attendance vs Event Attendance
          final dailyHistory = allHistory.where(_isDaily).toList();
          final eventHistory =
              allHistory.where((r) => !_isDaily(r)).toList();

          final isNavBarHidden = ref.watch(shellNavBarHiddenProvider);
          return SafeArea(
            top: false,
            bottom: false,
            left: false,
            right: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 12, 16, isNavBarHidden ? 28 : 110),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 800;

                  final dailySection = _buildAttendanceSection(
                    categoryTitle: 'Daily Attendance',
                    isDaily: true,
                    history: dailyHistory,
                    selectedYear: _dailyYear,
                    onYearChanged: (y) => setState(() => _dailyYear = y),
                    selectedMonth: _dailyMonth,
                    onMonthChanged: (m) => setState(() => _dailyMonth = m),
                  );

                  final eventSection = _buildAttendanceSection(
                    categoryTitle: 'Event Attendance',
                    isDaily: false,
                    history: eventHistory,
                    selectedYear: _eventYear,
                    onYearChanged: (y) => setState(() => _eventYear = y),
                    selectedMonth: _eventMonth,
                    onMonthChanged: (m) => setState(() => _eventMonth = m),
                  );

                  if (isWide) {
                    // Large screens: side by side
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: dailySection),
                        const SizedBox(width: 20),
                        Expanded(child: eventSection),
                      ],
                    );
                  } else {
                    // Small screens: daily attendance on top, event attendance on bottom
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        dailySection,
                        const SizedBox(height: 28),
                        eventSection,
                      ],
                    );
                  }
                },
              ),
            ),
          );
        },
      ),
    );
  }

  /// Builds a complete attendance section for a category (Daily or Event),
  /// containing the 12-month 2-column Bar Graph tile and Color-coded Calendar tile.
  Widget _buildAttendanceSection({
    required String categoryTitle,
    required bool isDaily,
    required List<Map<String, dynamic>> history,
    required int selectedYear,
    required ValueChanged<int> onYearChanged,
    required DateTime selectedMonth,
    required ValueChanged<DateTime> onMonthChanged,
  }) {
    final totalSessions = history.length;
    final presentSessions =
        history.where((r) => r['present'] == true).length;
    final overallPercent = totalSessions > 0
        ? ((presentSessions / totalSessions) * 100).round()
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Header Badge & Title
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: (isDaily ? _cyan : _purple).withOpacity(0.20),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isDaily
                          ? Icons.calendar_today_rounded
                          : Icons.event_available_rounded,
                      color: isDaily ? _cyan : _purple,
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      categoryTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _green.withOpacity(0.18),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _green.withOpacity(0.4)),
              ),
              child: Text(
                '$overallPercent% ($presentSessions/$totalSessions)',
                style: const TextStyle(
                  color: _green,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 1. Bar Graph Tile: 12 Months 2-Column Bar Graph (No. of days vs Attended days)
        _buildYearlyBarGraphTile(
          category: categoryTitle,
          history: history,
          selectedYear: selectedYear,
          onYearChanged: onYearChanged,
        ),
        const SizedBox(height: 16),

        // 2. Calendar Tile: Color-coded days for Present, Absent, and Normal days
        _buildCalendarTile(
          category: categoryTitle,
          isDaily: isDaily,
          history: history,
          selectedMonth: selectedMonth,
          onMonthChanged: onMonthChanged,
        ),
      ],
    );
  }

  /// 1. Yearly 2-Column Bar Graph Tile:
  /// Shows 12 months with 2 bars per month (Total days vs Attended days),
  /// with numbers and months on x-axis.
  Widget _buildYearlyBarGraphTile({
    required String category,
    required List<Map<String, dynamic>> history,
    required int selectedYear,
    required ValueChanged<int> onYearChanged,
  }) {
    // Calculate monthly data for the selected year
    final monthlyTotal = List<int>.filled(12, 0);
    final monthlyAttended = List<int>.filled(12, 0);

    for (final r in history) {
      final date = _dateOf(r);
      if (date != null && date.year == selectedYear) {
        final monthIdx = date.month - 1; // 0..11
        monthlyTotal[monthIdx]++;
        if (r['present'] == true) {
          monthlyAttended[monthIdx]++;
        }
      }
    }

    var maxMonthVal = 1;
    for (final val in monthlyTotal) {
      if (val > maxMonthVal) maxMonthVal = val;
    }

    return Container(
      decoration: BoxDecoration(
        color: _cardDark.withOpacity(0.70),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E5BB0).withOpacity(0.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title, Legend, and Year Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monthly Breakdown',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Total Days vs Attended Days',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Year Navigator: < 2026 >
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded,
                        color: Colors.white70, size: 22),
                    onPressed: () => onYearChanged(selectedYear - 1),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$selectedYear',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded,
                        color: Colors.white70, size: 22),
                    onPressed: () => onYearChanged(selectedYear + 1),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Legend Row
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _cyan,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              const SizedBox(width: 5),
              const Text('Total Days',
                  style: TextStyle(color: Colors.white70, fontSize: 11)),
              const SizedBox(width: 16),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _purple,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              const SizedBox(width: 5),
              const Text('Attended Days',
                  style: TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 16),

          // 12 Months 2-Column Bar Graph
          SizedBox(
            height: 155,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(12, (index) {
                  final total = monthlyTotal[index];
                  final attended = monthlyAttended[index];

                  const maxBarHeight = 90.0;
                  final totalBarHeight = total == 0
                      ? 4.0
                      : ((total / maxMonthVal) * maxBarHeight)
                          .clamp(6.0, maxBarHeight);
                  final attendedBarHeight = attended == 0
                      ? 4.0
                      : ((attended / maxMonthVal) * maxBarHeight)
                          .clamp(6.0, maxBarHeight);

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 34,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Numbers on top of the bars
                        Text(
                          total > 0 ? '$total/$attended' : '-',
                          style: TextStyle(
                            color: total > 0 ? Colors.white70 : Colors.white24,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // 2 Columns: Total (Cyan) and Attended (Purple)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Total Column
                            Container(
                              width: 12,
                              height: totalBarHeight,
                              decoration: BoxDecoration(
                                color: total > 0 ? _cyan : Colors.white12,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4)),
                              ),
                            ),
                            const SizedBox(width: 3),
                            // Attended Column
                            Container(
                              width: 12,
                              height: attendedBarHeight,
                              decoration: BoxDecoration(
                                color: attended > 0 ? _purple : Colors.white10,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Month Label on X-Axis
                        Text(
                          _monthNames[index],
                          style: TextStyle(
                            color: total > 0 ? Colors.white : Colors.white54,
                            fontSize: 10.5,
                            fontWeight: total > 0
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 2. Color-Coded Calendar Tile:
  /// Present = Green tint, Absent = Red tint, Normal = Subtle dark glass.
  Widget _buildCalendarTile({
    required String category,
    required bool isDaily,
    required List<Map<String, dynamic>> history,
    required DateTime selectedMonth,
    required ValueChanged<DateTime> onMonthChanged,
  }) {
    final daysInMonth =
        DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
    final firstWeekday =
        DateTime(selectedMonth.year, selectedMonth.month, 1).weekday; // 1..7

    // Build map for records on each day of this month
    final monthRecords = <int, List<Map<String, dynamic>>>{};
    for (final r in history) {
      final d = _dateOf(r);
      if (d != null &&
          d.year == selectedMonth.year &&
          d.month == selectedMonth.month) {
        monthRecords.putIfAbsent(d.day, () => []).add(r);
      }
    }

    var monthPresentCount = 0;
    var monthAbsentCount = 0;
    for (final list in monthRecords.values) {
      for (final r in list) {
        if (r['present'] == true) {
          monthPresentCount++;
        } else {
          monthAbsentCount++;
        }
      }
    }

    final today = DateTime.now();

    return Container(
      decoration: BoxDecoration(
        color: _cardDark.withOpacity(0.70),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E5BB0).withOpacity(0.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month Navigation Header: < Sep 2026 >
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => onMonthChanged(
                      DateTime(selectedMonth.year, selectedMonth.month - 1, 1),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      color: Colors.transparent,
                      child: const Icon(Icons.chevron_left_rounded,
                          color: Colors.white70, size: 22),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_monthNames[selectedMonth.month - 1]} ${selectedMonth.year}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => onMonthChanged(
                      DateTime(selectedMonth.year, selectedMonth.month + 1, 1),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      color: Colors.transparent,
                      child: const Icon(Icons.chevron_right_rounded,
                          color: Colors.white70, size: 22),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              // Month status pill
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _green.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$monthPresentCount P',
                      style: const TextStyle(
                        color: _green,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _red.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$monthAbsentCount A',
                      style: const TextStyle(
                        color: _red,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Weekday Labels (Mon, Tue, Wed, Thu, Fri, Sat, Sun)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _weekDays
                .map((day) => Expanded(
                      child: Text(
                        day,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),

          // Calendar Days Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 1.1,
            ),
            itemCount: (firstWeekday - 1) + daysInMonth,
            itemBuilder: (context, index) {
              if (index < firstWeekday - 1) {
                // Empty offset slot for days before the 1st
                return const SizedBox();
              }

              final day = index - (firstWeekday - 1) + 1;
              final recordsForDay = monthRecords[day] ?? [];

              final isToday = today.year == selectedMonth.year &&
                  today.month == selectedMonth.month &&
                  today.day == day;

              // Determine Day Status: Present, Absent, or Normal
              Color bgColor;
              Color fgColor;
              Border? border;

              if (recordsForDay.isNotEmpty) {
                final hasPresent = recordsForDay.any((r) => r['present'] == true);
                if (hasPresent) {
                  // Present Day: Emerald Green tint
                  bgColor = _green.withOpacity(0.80);
                  fgColor = Colors.white;
                } else {
                  // Absent Day: Red tint
                  bgColor = _red.withOpacity(0.80);
                  fgColor = Colors.white;
                }
              } else {
                // Normal Day: subtle dark glass
                bgColor = Colors.white.withOpacity(0.06);
                fgColor = Colors.white70;
              }

              if (isToday) {
                border = Border.all(color: _cyan, width: 1.6);
              }

              return InkWell(
                key: Key('calendar_day_${isDaily ? "daily" : "event"}_$day'),
                onTap: () {
                  final targetDate =
                      DateTime(selectedMonth.year, selectedMonth.month, day);
                  _showDayDetailsModal(
                    context,
                    date: targetDate,
                    recordsForDay: recordsForDay,
                    category: category,
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: border,
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          color: fgColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                      ),
                      if (recordsForDay.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),

          // Legend: Present, Absent, Normal Day
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 6,
              children: [
                _legendDot(_green, 'Present'),
                _legendDot(_red, 'Absent'),
                _legendDot(Colors.white.withOpacity(0.20), 'Normal Day'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }
}
