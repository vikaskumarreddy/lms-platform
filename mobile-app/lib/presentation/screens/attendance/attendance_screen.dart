import 'package:flutter/material.dart';
import '../../../core/widgets/common_header.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  String _selectedPeriod = 'Monthly';
  final List<String> _periods = ['Weekly', 'Monthly', 'Overall'];

  final List<_AttendanceRecord> _records = [
    _AttendanceRecord(subject: 'Java Programming', date: '15 Jan 2026', status: 'Present', percentage: 95),
    _AttendanceRecord(subject: 'Data Structures', date: '15 Jan 2026', status: 'Present', percentage: 88),
    _AttendanceRecord(subject: 'Database Management', date: '14 Jan 2026', status: 'Absent', percentage: 78),
    _AttendanceRecord(subject: 'Web Development', date: '14 Jan 2026', status: 'Present', percentage: 92),
    _AttendanceRecord(subject: 'Software Engineering', date: '13 Jan 2026', status: 'Late', percentage: 85),
    _AttendanceRecord(subject: 'Advanced Java', date: '13 Jan 2026', status: 'Present', percentage: 90),
  ];

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF0F172A);
    final secondaryColor = const Color(0xFFEAB308);

    return Scaffold(
      appBar: const CommonHeader(title: 'Attendance'),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.grey.shade50),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search subjects...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedPeriod,
                      items: _periods.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                      onChanged: (v) => setState(() => _selectedPeriod = v!),
                    ),
                  ),
                ),
              ],
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
                          const Text('Present', style: TextStyle(color: Colors.white, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text('85%', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    color: Colors.red,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text('Absent', style: TextStyle(color: Colors.white, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text('10%', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    color: Colors.orange,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text('Late', style: TextStyle(color: Colors.white, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text('5%', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Weekly Overview', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: primaryColor)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _WeekDayBar(day: 'Mon', percentage: 100, color: Colors.green)),
                        const SizedBox(width: 8),
                        Expanded(child: _WeekDayBar(day: 'Tue', percentage: 80, color: Colors.green)),
                        const SizedBox(width: 8),
                        Expanded(child: _WeekDayBar(day: 'Wed', percentage: 100, color: Colors.green)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _WeekDayBar(day: 'Thu', percentage: 60, color: Colors.red)),
                        const SizedBox(width: 8),
                        Expanded(child: _WeekDayBar(day: 'Fri', percentage: 100, color: Colors.green)),
                        const SizedBox(width: 8),
                        Expanded(child: _WeekDayBar(day: 'Sat', percentage: 0, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Recent Attendance', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: primaryColor)),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _records.length,
              itemBuilder: (context, index) {
                final record = _records[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: record.status == 'Present' ? Colors.green : record.status == 'Absent' ? Colors.red : Colors.orange,
                      child: Icon(record.status == 'Present' ? Icons.check : record.status == 'Absent' ? Icons.close : Icons.watch_later, color: Colors.white),
                    ),
                    title: Text(record.subject, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(record.date),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(record.status, style: TextStyle(color: record.status == 'Present' ? Colors.green : record.status == 'Absent' ? Colors.red : Colors.orange, fontWeight: FontWeight.bold)),
                        Text('${record.percentage}%', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceRecord {
  final String subject;
  final String date;
  final String status;
  final int percentage;

  _AttendanceRecord({
    required this.subject,
    required this.date,
    required this.status,
    required this.percentage,
  });
}

class _WeekDayBar extends StatelessWidget {
  final String day;
  final int percentage;
  final Color color;
  const _WeekDayBar({required this.day, required this.percentage, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$percentage%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Container(
          height: 100,
          width: double.infinity,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: percentage / 100,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(day, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }
}
