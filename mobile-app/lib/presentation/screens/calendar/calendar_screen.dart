import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/api_service.dart';
import '../../../data/models/event_model.dart';
import '../../../core/widgets/common_header.dart';
import '../browser/in_app_browser_screen.dart';

/// Calendar palette aligned with the dashboard's navy/blue glass theme.
const Color kCalBackground = Color(0xFF071D43);
const Color kCalSurface = Color(0xFF104476);
const Color kCalPurple = Color(0xFF9B5CFF);
const Color kCalCyan = Color(0xFF27D9D3);
const Color kCalYellow = Color(0xFFFFCF35);
// Kept for legacy, unused calendar widgets below the active reference layout.
const Color kCalGreenDark = kCalCyan;
const Color kCalCream = kCalSurface;
const Color kCalOrange = kCalYellow;

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _currentMonth;
  late DateTime _selectedDate;
  bool _loading = true;
  late final PageController _monthPager;
  late final DateTime _pagerBaseMonth;

  final List<String> _monthNames = const [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  final List<String> _weekdays = const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  List<_CalendarEvent> _allEvents = [];
  Map<int, bool> _attendanceByEventId = {};
  final Set<_EventItem> _expandedEvents = <_EventItem>{};

  @override
  void initState() {
    super.initState();
    // Open on the real current month/date so the live events are immediately visible.
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month, 1);
    _selectedDate = DateTime(now.year, now.month, now.day);
    _pagerBaseMonth =
        DateTime(DateTime.now().year, DateTime.now().month - 60, 1);
    _monthPager = PageController(initialPage: 60);
    _loadEvents();
  }

  @override
  void dispose() {
    _monthPager.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    List<EventModel> events;
    try {
      events = await ApiService().getEvents();
    } catch (_) {
      events = [];
    }

    try {
      final attendance = await ApiService().getAttendanceHistory();
      final rawHistory = attendance['history'];
      final history = rawHistory is List
          ? rawHistory.whereType<Map>().map((h) => Map<String, dynamic>.from(h)).toList()
          : <Map<String, dynamic>>[];
      _attendanceByEventId = {
        for (final h in history)
          if (h['eventId'] is num)
            (h['eventId'] as num).toInt(): h['present'] == true,
      };
    } catch (_) {
      // Events still render if attendance history is temporarily unavailable.
      _attendanceByEventId = {};
    }

    if (!mounted) return;
    setState(() {
      _allEvents = _groupByMonth(events);
      _loading = false;
    });
  }

  List<_CalendarEvent> _groupByMonth(List<EventModel> events) {
    final grouped = <String, List<_CalendarEvent>>{};
    for (final e in events) {
      final dt = DateTime.tryParse(e.startTime ?? '');
      if (dt == null) continue;
      final monthKey = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      final day = dt.day.toString().padLeft(2, '0');
      final dateLabel = e.date;
      final item = _toEventItem(e, dt);
      final group = grouped.putIfAbsent(monthKey, () => []);

      final existingIndex = group.indexWhere((g) => g.day == day);
      if (existingIndex >= 0) {
        group[existingIndex].items.add(item);
      } else {
        group.add(_CalendarEvent(
          day: day,
          date: dateLabel,
          monthKey: monthKey,
          items: [item],
        ));
      }
    }
    grouped.forEach((key, list) => list.sort((a, b) => a.day.compareTo(b.day)));
    return grouped.values.expand((g) => g).toList();
  }

  Color _eventColor(String? type) {
    switch ((type ?? '').toLowerCase()) {
      case 'exam':
      case 'test':
        return Colors.red;
      case 'placement':
      case 'drive':
        return Colors.green;
      case 'holiday':
        return Colors.purple;
      case 'interview':
        return Colors.orange;
      case 'class':
      case 'workshop':
      case 'webinar':
      case 'live':
        return Colors.blue;
      default:
        return const Color(0xFF10B981);
    }
  }

  _EventItem _toEventItem(EventModel e, DateTime dt) {
    final now = DateTime.now();
    final isPast = dt.isBefore(now);
    final attendance = _attendanceByEventId[e.id];
    String status;
    if (attendance != null) {
      status = attendance ? 'Attended' : 'Missed';
    } else if (isPast) {
      status = 'Completed';
    } else {
      status = 'Upcoming';
    }
    return _EventItem(
      title: e.title,
      time: e.time.isEmpty ? 'All Day' : e.time,
      color: _eventColor(e.eventType),
      type: e.eventType ?? 'Event',
      venue: (e.venue ?? '').trim(),
      isPast: isPast,
      meetLink: e.meetLink ?? '',
      status: status,
    );
  }

  String get _selectedMonthKey =>
      '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}';

  void _selectDay(DateTime day) => setState(() => _selectedDate = day);

  DateTime _monthForPage(int page) => DateTime(_pagerBaseMonth.year, _pagerBaseMonth.month + page, 1);

  void _onMonthPageChanged(int page) {
    final month = _monthForPage(page);
    setState(() {
      _currentMonth = month;
      final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
      final clampedDay = _selectedDate.day.clamp(1, daysInMonth);
      _selectedDate = DateTime(month.year, month.month, clampedDay);
    });
  }

  void _animateToMonth(DateTime month) {
    final diff = (month.year - _pagerBaseMonth.year) * 12 + (month.month - _pagerBaseMonth.month);
    if (_monthPager.hasClients) {
      _monthPager.animateToPage(diff, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    } else {
      setState(() => _currentMonth = DateTime(month.year, month.month, 1));
    }
  }

  void _openLink(String url, String title) {
    if (url.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InAppBrowserScreen(url: url, title: title),
      ),
    );
  }

  // ---------- helpers for the grid ----------

  /// Items scheduled on the currently selected date.
  List<_EventItem> get _selectedDayItems {
    final key = _selectedDate.day.toString().padLeft(2, '0');
    for (final e in _allEvents) {
      if (e.monthKey == _selectedMonthKey && e.day == key) return e.items;
    }
    return const [];
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    return CommonHeaderScaffold(
      subtitle: 'Calendar',
      backgroundColor: kCalBackground,
      body: Stack(children: [
        const Positioned.fill(child: _ReferenceCalendarBackdrop()),
        SafeArea(
          bottom: false,
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFB66BFF)))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(17, 12, 17, 90),
                  children: [
                    _buildReferenceMonthCard(),
                    const SizedBox(height: 15),
                    _buildReferenceTodayPanel(),
                  ],
                ),
        ),
      ]),
    );
  }

  Widget _buildReferenceHeader() => Row(children: [
        _referenceCircleButton(Icons.menu_rounded, () => mainScaffoldKey.currentState?.openDrawer()),
        const SizedBox(width: 12),
        Container(width: 45, height: 45, decoration: BoxDecoration(color: kCalPurple, borderRadius: BorderRadius.circular(13), boxShadow: [BoxShadow(color: kCalPurple.withOpacity(.55), blurRadius: 18)]), child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 25)),
        const SizedBox(width: 15),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('My Calendar', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)), SizedBox(height: 3), Text('Plan your goals, track your progress', style: TextStyle(color: Colors.white70, fontSize: 11))])),
        _referenceCircleButton(Icons.notifications_none_rounded, () {}),
        const SizedBox(width: 8),
        const CircleAvatar(radius: 16, backgroundColor: Colors.white, child: Icon(Icons.person, color: Color(0xFF27517C), size: 21)),
      ]);

  Widget _referenceCircleButton(IconData icon, VoidCallback onTap) => InkWell(onTap: onTap, customBorder: const CircleBorder(), child: SizedBox(width: 30, height: 35, child: Icon(icon, color: Colors.white.withOpacity(.9), size: 23)));

  Widget _buildReferenceMonthCard() {
    final month = _currentMonth;
    final first = DateTime(month.year, month.month, 1);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday % 7;
    final eventDays = <int, Color>{};
    for (final event in _allEvents.where((e) => e.monthKey == '${month.year}-${month.month.toString().padLeft(2, '0')}')) {
      final day = int.tryParse(event.day);
      if (day != null) eventDays[day] = event.items.first.color;
    }
    return _referenceGlassCard(child: Column(children: [
      Row(children: [Expanded(child: Text('${_monthNames[month.month]} ${month.year}', style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w800))), _referenceSmallButton(Icons.chevron_left_rounded, () => _animateToMonth(DateTime(month.year, month.month - 1))), _referenceSmallButton(Icons.chevron_right_rounded, () => _animateToMonth(DateTime(month.year, month.month + 1))), const SizedBox(width: 9), InkWell(onTap: () {
          final now = DateTime.now();
          _animateToMonth(DateTime(now.year, now.month, 1));
          _selectDay(DateTime(now.year, now.month, now.day));
        }, borderRadius: BorderRadius.circular(11), child: Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8), decoration: BoxDecoration(color: Colors.white.withOpacity(.09), border: Border.all(color: Colors.white12), borderRadius: BorderRadius.circular(11)), child: const Row(children: [Icon(Icons.calendar_month_outlined, color: Colors.white, size: 15), SizedBox(width: 5), Text('Today', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))]))) ]),
      const SizedBox(height: 15),
      Row(
        children: _weekdays
            .map((day) => Expanded(
                  child: Center(
                    child: Text(day,
                        style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                ))
            .toList(),
      ),
      const SizedBox(height: 8),
      Container(height: 1, color: Colors.white.withOpacity(.12)),
      const SizedBox(height: 7),
      ...List.generate(((leading + days) / 7).ceil(), (row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Row(
            children: List.generate(7, (col) {
              final number = row * 7 + col - leading + 1;
              if (number < 1 || number > days) {
                return const Expanded(child: SizedBox(height: 46));
              }
              final date = DateTime(month.year, month.month, number);
              final selected = _sameDay(date, _selectedDate);
              final dot = eventDays[number] ??
                  [
                    kCalPurple,
                    kCalCyan,
                    kCalCyan,
                    const Color(0xFFFFD34A),
                  ][number % 4];
              return Expanded(
                child: GestureDetector(
                  onTap: () => _selectDay(date),
                  child: Container(
                    height: 46,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF1389D4).withOpacity(.9)
                          : Colors.white.withOpacity(.045),
                      border: Border.all(
                          color: selected
                              ? const Color(0xFF21C7FF)
                              : Colors.white.withOpacity(.10)),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                  color:
                                      const Color(0xFF20B5FF).withOpacity(.7),
                                  blurRadius: 13)
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$number',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w600)),
                        const SizedBox(height: 4),
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                              color: dot,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: dot.withOpacity(.75), blurRadius: 5)
                              ]),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      }),
    ]));
  }

  Widget _referenceSmallButton(IconData icon, VoidCallback onTap) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(9), child: Container(width: 31, height: 31, decoration: BoxDecoration(color: Colors.white.withOpacity(.08), border: Border.all(color: Colors.white12), borderRadius: BorderRadius.circular(9)), child: Icon(icon, color: Colors.white, size: 19)));

  Widget _buildReferenceTodayPanel() {
    final items = _selectedDayItems;
    return _referenceGlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _referenceCircleIcon(Icons.calendar_month_rounded, kCalCyan),
          const SizedBox(width: 10),
          const Expanded(child: Text('Today', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800))),
          Text('${_weekdays[_selectedDate.weekday % 7]}, ${_selectedDate.day} ${_monthNames[_selectedDate.month]} ${_selectedDate.year}', style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(color: Colors.white.withOpacity(.055), borderRadius: BorderRadius.circular(13)),
          child: items.isEmpty
              ? const Row(children: [Icon(Icons.event_busy_outlined, color: Colors.white54, size: 22), SizedBox(width: 10), Text('No events scheduled for this day', style: TextStyle(color: Colors.white70, fontSize: 12))])
              : Column(children: List.generate(items.length, (i) => _referenceTimelineItem(items[i], i == items.length - 1))),
        ),
      ]),
    );
  }

  Widget _referenceTimelineItem(_EventItem item, bool last) {
    final expanded = _expandedEvents.contains(item);
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(width: 39, child: Column(children: [
          Container(width: 29, height: 29, decoration: BoxDecoration(color: item.color.withOpacity(.95), shape: BoxShape.circle, boxShadow: [BoxShadow(color: item.color.withOpacity(.5), blurRadius: 12)]), child: Icon(item.status == 'Completed' || item.status == 'Attended' ? Icons.check_rounded : Icons.circle_outlined, color: Colors.white, size: 17)),
          if (!last) Expanded(child: Container(width: 1, color: Colors.white24)),
        ])),
        const SizedBox(width: 9),
        Expanded(child: GestureDetector(
          onTap: () => setState(() {
            if (expanded) { _expandedEvents.remove(item); } else { _expandedEvents.add(item); }
          }),
          child: Container(padding: const EdgeInsets.only(bottom: 11, top: 1), decoration: last ? null : BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withOpacity(.13)))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)), const SizedBox(height: 4), Text(item.time, style: const TextStyle(color: Colors.white60, fontSize: 10))])), Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.white60, size: 18)]),
            if (expanded) ...[
              const SizedBox(height: 9),
              if (item.venue.isNotEmpty) _eventDetailLine(Icons.location_on_outlined, item.venue),
              _eventDetailLine(Icons.category_outlined, item.type),
              if (item.meetLink.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 9), child: Row(children: [OutlinedButton.icon(onPressed: () async { await Clipboard.setData(ClipboardData(text: item.meetLink)); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Meeting link copied'))); }, icon: const Icon(Icons.copy, size: 14), label: const Text('Copy link', style: TextStyle(fontSize: 10))), const SizedBox(width: 8), FilledButton.icon(onPressed: item.isPast ? null : () => _openLink(item.meetLink, item.title), icon: const Icon(Icons.login_rounded, size: 14), label: const Text('Attend', style: TextStyle(fontSize: 10))) ])),
            ],
          ])),
        )),
      ]),
    );
  }

  Widget _eventDetailLine(IconData icon, String value) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [Icon(icon, color: Colors.white60, size: 14), const SizedBox(width: 7), Expanded(child: Text(value, style: const TextStyle(color: Colors.white70, fontSize: 10)))]));

  Widget _referenceGlassCard({required Widget child}) => ClipRRect(borderRadius: BorderRadius.circular(16), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: kCalSurface.withOpacity(.70), border: Border.all(color: const Color(0xFF4D9CD0).withOpacity(.58)), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.16), blurRadius: 15)]), child: child)));

  Widget _referenceCircleIcon(IconData icon, Color color) => Container(width: 37, height: 37, decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(.5), blurRadius: 13)]), child: Icon(icon, color: Colors.white, size: 19));

  // ---------- month grid card (swipeable) ----------

  Widget _buildMonthCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF9CA97F),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 372,
            child: PageView.builder(
              controller: _monthPager,
              onPageChanged: _onMonthPageChanged,
              itemBuilder: (_, page) {
                final month = _monthForPage(page);
                return _buildMonthPage(month);
              },
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 90,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthPage(DateTime month) {
    final key =
        '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final byDay = <int, List<_EventItem>>{};
    for (final e in _allEvents) {
      if (e.monthKey == key) byDay[int.parse(e.day)] = e.items;
    }
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = first.weekday % 7;
    final totalCells = leadingBlanks + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '${_monthNames[month.month]} ${month.year}',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2),
          ),
        ),
            const SizedBox(height: 18),
            Row(
              children: _weekdays
                  .map((d) => Expanded(
                        child: Center(
                          child: Text(d,
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.75),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 10),
            const Divider(color: Colors.white24, height: 1, thickness: 0.6),
            const SizedBox(height: 12),
            ...List.generate(rows, (row) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: List.generate(7, (col) {
                    final index = row * 7 + col - leadingBlanks;
                    if (index < 0 || index >= daysInMonth) {
                      return const Expanded(child: SizedBox(height: 48));
                    }
                    final day = index + 1;
                    final date = DateTime(month.year, month.month, day);
                    final isSelected = _sameDay(date, _selectedDate);
                    final isToday = _sameDay(date, DateTime.now());
                    final dayItems = byDay[day] ?? const <_EventItem>[];
                    final hasEvent = dayItems.isNotEmpty;

                    return Expanded(
                      child: GestureDetector(
                        onTap: () => _selectDay(date),
                        behavior: HitTestBehavior.opaque,
                        child: SizedBox(
                          height: 48,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isSelected
                                    ? const Color(0xFF7D8A5C)
                                    : Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '$day',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              SizedBox(
                                height: 5,
                                child: hasEvent
                                  ? Container(
                                    width: 5,
                                    height: 5,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              );
            }),
          ],
        );
  }

  // ---------- today / selected-day panel ----------

  Widget _buildTodayPanel() {
    final items = _selectedDayItems;
    final isToday = _sameDay(_selectedDate, DateTime.now());
    final label = isToday
        ? 'Today'
        : '${_weekdays[_selectedDate.weekday % 7]}, ${_selectedDate.day} ${_monthNames[_selectedDate.month]}';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCalSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF3A3A2E))),
          const SizedBox(height: 4),
          Text(
            items.isEmpty ? 'No events scheduled' : '${items.length} event${items.length > 1 ? 's' : ''}',
            style: TextStyle(fontSize: 13, color: Colors.brown.shade400),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy, size: 40, color: Colors.brown.shade300),
                        const SizedBox(height: 8),
                        Text('Nothing planned for this day',
                            style: TextStyle(color: Colors.brown.shade400, fontSize: 13)),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _buildTimelineEvent(items[i]),
                  ),
          ),
        ],
      ),
    );
  }
  Widget _buildTimelineEvent(_EventItem item) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.brown.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 58,
            child: Text(item.time,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF3A3A2E))),
          ),
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(top: 3),
                decoration: BoxDecoration(shape: BoxShape.circle, color: item.color),
              ),
              Container(width: 2, height: 52, color: item.color.withOpacity(0.3)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF3A3A2E))),
                const SizedBox(height: 4),
                Text(item.type, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor(item.status).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(item.status,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _statusColor(item.status))),
                    ),
                    const Spacer(),
                    if (item.meetLink.isNotEmpty && !item.isPast)
                      GestureDetector(
                        onTap: () => _openLink(item.meetLink, item.title),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: kCalGreenDark,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('Join',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Attended':
        return const Color(0xFF4CAF50);
      case 'Missed':
        return const Color(0xFFE05252);
      case 'Completed':
        return Colors.grey.shade600;
      default:
        return kCalOrange;
    }
  }
}

class _ReferenceCalendarBackdrop extends StatelessWidget {
  const _ReferenceCalendarBackdrop();
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _ReferenceCalendarBackdropPainter());
}

class _ReferenceCalendarBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..shader = const RadialGradient(colors: [Color(0xFF0C4B91), Color(0xFF061D43)], radius: 1.1).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);
    for (final point in [Offset(size.width * .2, size.height * .12), Offset(size.width * .82, size.height * .28), Offset(size.width * .08, size.height * .54), Offset(size.width * .72, size.height * .72)]) {
      canvas.drawCircle(point, 72, Paint()..color = const Color(0xFF257BB9).withOpacity(.12)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 35));
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CalendarEvent {
  final String day;
  final String date;
  final String monthKey;
  final List<_EventItem> items;
  _CalendarEvent({required this.day, required this.date, required this.monthKey, required this.items});
}

class _EventItem {
  final String title;
  final String time;
  final Color color;
  final String venue;
  final String type;
  final bool isPast;
  final String meetLink;
  final String status;
  _EventItem({required this.title, required this.time, required this.color, this.venue = '', required this.type, required this.isPast, required this.meetLink, required this.status});
}
