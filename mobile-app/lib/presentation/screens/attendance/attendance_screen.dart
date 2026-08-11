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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
          final history = (attendanceData['history'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>()
              .where((h) => _query.isEmpty || (h['eventTitle']?.toString().toLowerCase() ?? '').contains(_query.toLowerCase()))
              .toList();
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
