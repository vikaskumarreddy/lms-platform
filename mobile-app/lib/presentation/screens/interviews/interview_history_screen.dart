import 'package:flutter/material.dart';
import '../../../core/widgets/common_header.dart';

class InterviewHistoryScreen extends StatefulWidget {
  const InterviewHistoryScreen({super.key});

  @override
  State<InterviewHistoryScreen> createState() => _InterviewHistoryScreenState();
}

class _InterviewHistoryScreenState extends State<InterviewHistoryScreen> {
  String _selectedTab = 'Upcoming';
  final List<_InterviewItem> _interviews = [
    _InterviewItem(id: 1, company: 'TCS', date: '20 Jan 2026', time: '10:00 AM', type: 'Technical', status: 'Upcoming', round: 'Round 1'),
    _InterviewItem(id: 2, company: 'Infosys', date: '22 Jan 2026', time: '02:00 PM', type: 'HR', status: 'Upcoming', round: 'Round 2'),
    _InterviewItem(id: 3, company: 'Wipro', date: '15 Jan 2026', time: '11:00 AM', type: 'Technical', status: 'Completed', round: 'Round 1', result: 'Selected'),
    _InterviewItem(id: 4, company: 'Cognizant', date: '10 Jan 2026', time: '09:00 AM', type: 'Technical', status: 'Completed', round: 'Final', result: 'On Hold'),
  ];

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF0F172A);

    return Scaffold(
      appBar: const CommonHeader(title: 'Interview History'),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.grey.shade50),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search interviews...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TabButton(title: 'Upcoming', isSelected: _selectedTab == 'Upcoming', onTap: () => setState(() => _selectedTab = 'Upcoming')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TabButton(title: 'Completed', isSelected: _selectedTab == 'Completed', onTap: () => setState(() => _selectedTab = 'Completed')),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _interviews.where((i) => i.status == _selectedTab).length,
              itemBuilder: (context, index) {
                final interview = _interviews.where((i) => i.status == _selectedTab).toList()[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: primaryColor,
                              child: Text(interview.company[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(interview.company, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text(interview.round, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: interview.status == 'Upcoming' ? Colors.blue.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(interview.status, style: TextStyle(fontSize: 11, color: interview.status == 'Upcoming' ? Colors.blue : Colors.green, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(interview.date, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                            const SizedBox(width: 16),
                            Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(interview.time, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.category, size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(interview.type, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                            if (interview.result != null) ...[
                              const SizedBox(width: 16),
                              Icon(Icons.check_circle, size: 16, color: Colors.green),
                              const SizedBox(width: 4),
                              Text(interview.result!, style: TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.bold)),
                            ],
                          ],
                        ),
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

class _TabButton extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  const _TabButton({required this.title, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(color: isSelected ? Colors.white : Colors.grey.shade600, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
        ),
      ),
    );
  }
}

class _InterviewItem {
  final int id;
  final String company;
  final String date;
  final String time;
  final String type;
  final String status;
  final String round;
  final String? result;

  _InterviewItem({
    required this.id,
    required this.company,
    required this.date,
    required this.time,
    required this.type,
    required this.status,
    required this.round,
    this.result,
  });
}