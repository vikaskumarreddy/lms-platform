import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../data/models/event_model.dart';
import '../../../core/widgets/common_header.dart';
import '../browser/in_app_browser_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  int? _selectedEventIndex;
  late DateTime _currentMonth;
  late DateTime _selectedDate;

  final List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  List<_CalendarEvent> _allEvents = [];

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    _selectedDate = DateTime.now();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    List<EventModel> events;
    try {
      events = await ApiService().getEvents();
    } catch (_) {
      events = [];
    }
    final grouped = <String, List<_CalendarEvent>>{};
    for (final e in events) {
      final dt = DateTime.tryParse(e.startTime ?? '');
      if (dt == null) continue;
      final monthKey =
          '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      final day = dt.day.toString().padLeft(2, '0');
      final dateLabel = e.date;
      final item = _toEventItem(e, dt);
      final group = grouped.putIfAbsent(monthKey, () => []);
      final existing = group.indexWhere((g) => g.day == day);
      if (existing >= 0) {
        group[existing].items.add(item);
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
    if (!mounted) return;
    setState(() {
      _allEvents = grouped.values.expand((g) => g).toList();
    });
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
    return _EventItem(
      title: e.title,
      time: e.time.isEmpty ? 'All Day' : e.time,
      color: _eventColor(e.eventType),
      type: e.eventType ?? 'Event',
      isPast: isPast,
      meetLink: e.meetLink ?? '',
      status: isPast ? 'Completed' : 'Upcoming',
    );
  }

  String get _monthKey => '${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}';

  String get _monthYearString => '${_monthNames[_currentMonth.month - 1]} ${_currentMonth.year}';

  List<_CalendarEvent> get _currentMonthEvents {
    return _allEvents.where((e) => e.monthKey == _monthKey).toList();
  }

  void _goToPreviousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
      _selectedEventIndex = null;
    });
  }

  void _goToNextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
      _selectedEventIndex = null;
    });
  }

  void _openLink(String url, String title) {
    if (url.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InAppBrowserScreen(url: url, title: title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF0F172A);
    final events = _currentMonthEvents;
    return Scaffold(
      appBar: const CommonHeader(title: 'Calendar'),
      body: Column(children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [primaryColor, primaryColor.withOpacity(0.8)]),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                onPressed: _goToPreviousMonth,
              ),
              Text(_monthYearString, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white),
                onPressed: _goToNextMonth,
              ),
            ],
          ),
        ),
        Expanded(
          child: events.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('No events in $_monthYearString', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: events.asMap().entries.map((entry) => _buildDateSection(entry.key, entry.value)).toList(),
                ),
        ),
      ]),
    );
  }

  Widget _buildDateSection(int dateIndex, _CalendarEvent event) {
    final isSelected = _selectedEventIndex == dateIndex;
    final secondaryColor = const Color(0xFFEAB308);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected ? BorderSide(color: secondaryColor, width: 2) : BorderSide.none,
      ),
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _selectedEventIndex = isSelected ? null : dateIndex),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(8)),
                child: Text(event.date, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(event.day, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${event.items.length} events', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ]),
              ),
              Icon(isSelected ? Icons.expand_less : Icons.expand_more, color: secondaryColor),
            ]),
          ),
        ),
        if (isSelected)
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Column(
              children: event.items.map((item) => _buildEventDetail(item)).toList(),
            ),
          ),
      ]),
    );
  }

  Widget _buildEventDetail(_EventItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 4, height: 40, decoration: BoxDecoration(color: item.color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: item.isPast ? (item.status == 'Attended' ? Colors.green : Colors.red.shade300) : const Color(0xFFEAB308),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(item.status, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ]),
          ),
        ]),
        if (item.meetLink.isNotEmpty)
          Column(children: [
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.videocam, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Expanded(
                child: InkWell(
                  onTap: () => _openLink(item.meetLink, item.title),
                  child: Text(item.meetLink, style: TextStyle(fontSize: 12, color: Colors.blue.shade600, decoration: TextDecoration.underline)),
                ),
              ),
              if (!item.isPast)
                ElevatedButton(
                  onPressed: () => _openLink(item.meetLink, item.title),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEAB308),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('Join', style: TextStyle(fontSize: 11)),
                ),
            ]),
          ]),
      ]),
    );
  }
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
  final String type;
  final bool isPast;
  final String meetLink;
  final String status;
  _EventItem({required this.title, required this.time, required this.color, required this.type, required this.isPast, required this.meetLink, required this.status});
}