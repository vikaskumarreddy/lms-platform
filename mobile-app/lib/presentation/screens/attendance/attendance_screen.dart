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
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  String? _selectedSubject;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  DateTime _viewMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String? _isoDateOf(Map<String, dynamic> record) {
    final startTime = record['startTime']?.toString();
    if (startTime == null || startTime.length < 10) return null;
    return startTime.substring(0, 10);
  }

  List<String> _subjectOptions(List<Map<String, dynamic>> history) {
    final subjects = <String>{};
    for (final r in history) {
      final s = r['subject']?.toString();
      if (s != null && s.isNotEmpty) subjects.add(s);
    }
    final list = subjects.toList()..sort();
    return list;
  }

  List<Map<String, dynamic>> _dailyFiltered(List<Map<String, dynamic>> history) {
    return history.where((r) {
      final isoDate = _isoDateOf(r);
      if (isoDate == null) return false;
      if (_selectedSubject != null && r['subject']?.toString() != _selectedSubject) return false;
      if (_dateFrom != null && isoDate.compareTo(_dateFrom!.toIso8601String().substring(0, 10)) < 0) return false;
      if (_dateTo != null && isoDate.compareTo(_dateTo!.toIso8601String().substring(0, 10)) > 0) return false;
      return true;
    }).toList();
  }

  double _dailyPercent(List<Map<String, dynamic>> filtered) {
    if (filtered.isEmpty) return 0;
    final present = filtered.where((r) => r['present'] == true).length;
    return (present / filtered.length * 1000).round() / 10;
  }

  Map<String, bool> _monthAttendanceMap(List<Map<String, dynamic>> history) {
    final map = <String, bool>{};
    for (final r in history) {
      if (_selectedSubject != null && r['subject']?.toString() != _selectedSubject) continue;
      final isoDate = _isoDateOf(r);
      if (isoDate == null) continue;
      map[isoDate] = r['present'] == true;
    }
    return map;
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = (isFrom ? _dateFrom : _dateTo) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _dateFrom = picked;
        } else {
          _dateTo = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF0F172A);
    final attendanceAsync = ref.watch(attendanceHistoryProvider);

    return Scaffold(
      appBar: const CommonHeader(title: 'Attendance'),
      body: attendanceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text('Failed to load attendance', style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              TextButton(onPressed: () => ref.invalidate(attendanceHistoryProvider), child: const Text('Retry')),
            ],
          ),
        ),
        data: (attendanceData) {
          final percentage = ((attendanceData['percentage'] as num?) ?? 0).round();
          final presentCount = ((attendanceData['presentCount'] as num?) ?? 0).toInt();
          final absentCount = ((attendanceData['absentCount'] as num?) ?? 0).toInt();
          final totalEvents = ((attendanceData['totalEvents'] as num?) ?? 0).toInt();
          final allHistory = (attendanceData['history'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>()
              .toList();
          final history = allHistory
              .where((h) => _query.isEmpty || (h['eventTitle']?.toString().toLowerCase() ?? '').contains(_query.toLowerCase()))
              .toList();
          final subjectOptions = _subjectOptions(allHistory);
          final dailyFiltered = _dailyFiltered(allHistory);
          final dailyPercent = _dailyPercent(dailyFiltered);
          final monthMap = _monthAttendanceMap(allHistory);
          final daysInMonth = DateTime(_viewMonth.year, _viewMonth.month + 1, 0).day;
          const monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
          return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.grey.shade50),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search classes...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Card(
                    color: Colors.green,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text('Overall', style: TextStyle(color: Colors.white, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text('$percentage%', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text('Present / Total', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text('$presentCount/$totalEvents', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: primaryColor)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Absent: $absentCount classes', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ),
          const SizedBox(height: 20),
          if (subjectOptions.isNotEmpty || dailyFiltered.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('Daily Attendance', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: primaryColor)),
            ),
            const SizedBox(height: 12),
            if (subjectOptions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: _selectedSubject == null,
                      onSelected: (_) => setState(() => _selectedSubject = null),
                    ),
                    ...subjectOptions.map((s) => ChoiceChip(
                          label: Text(s),
                          selected: _selectedSubject == s,
                          onSelected: (_) => setState(() => _selectedSubject = s),
                        )),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickDate(isFrom: true),
                      child: Text(_dateFrom == null ? 'From date' : _formatDate(_dateFrom!.toIso8601String())),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickDate(isFrom: false),
                      child: Text(_dateTo == null ? 'To date' : _formatDate(_dateTo!.toIso8601String())),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '$dailyPercent% attended (${dailyFiltered.length} days)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setState(() => _viewMonth = DateTime(_viewMonth.year, _viewMonth.month - 1, 1)),
                  ),
                  Text(
                    '${monthNames[_viewMonth.month - 1]} ${_viewMonth.year}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => setState(() => _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + 1, 1)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                ),
                itemCount: daysInMonth,
                itemBuilder: (context, index) {
                  final day = index + 1;
                  final isoDate = '${_viewMonth.year}-${_viewMonth.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
                  final present = monthMap[isoDate];
                  final bg = present == null
                      ? Colors.grey.shade100
                      : (present ? Colors.green.shade100 : Colors.red.shade100);
                  final fg = present == null
                      ? Colors.grey.shade600
                      : (present ? Colors.green.shade700 : Colors.red.shade700);
                  return Container(
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
                    alignment: Alignment.center,
                    child: Text('$day', style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 12)),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Class History', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: primaryColor)),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: history.isEmpty
                ? Center(child: Text('No attendance records yet', style: TextStyle(color: Colors.grey.shade600)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final record = history[index];
                      final present = record['present'] == true;
                      final title = record['eventTitle']?.toString() ?? 'Class';
                      final type = record['eventType']?.toString() ?? 'Class';
                      final startTime = record['startTime']?.toString() ?? '';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: present ? Colors.green : Colors.red,
                            child: Icon(present ? Icons.check : Icons.close, color: Colors.white),
                          ),
                          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('$type • ${_formatDate(startTime)}'),
                          trailing: Text(
                            present ? 'Attended' : 'Missed',
                            style: TextStyle(color: present ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
          );
        },
      ),
    );
  }

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}
