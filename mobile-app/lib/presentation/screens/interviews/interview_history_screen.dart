import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/routes.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/common_header.dart';

class InterviewHistoryScreen extends StatefulWidget {
  const InterviewHistoryScreen({super.key});

  @override
  State<InterviewHistoryScreen> createState() => _InterviewHistoryScreenState();
}

class _InterviewHistoryScreenState extends State<InterviewHistoryScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();
  String _selectedTab = 'Upcoming';
  String _searchQuery = '';
  bool _loading = true;
  List<_InterviewItem> _interviews = [];

  @override
  void initState() {
    super.initState();
    _loadInterviews();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInterviews() async {
    setState(() => _loading = true);
    final raw = await _api.getMyInterviewHistory();
    if (!mounted) return;

    final interviews = raw.map((entry) {
      final status = (entry['status'] as String?) ?? 'BOOKED';
      final slotTime = DateTime.tryParse((entry['slotTime'] as String?) ?? '');
      return _InterviewItem(
        id: (entry['id'] as num?)?.toInt() ?? 0,
        company: (entry['companyName'] as String?) ?? 'Unknown Company',
        role: (entry['role'] as String?) ?? '',
        location: (entry['location'] as String?) ?? '',
        slotTime: slotTime,
        status: status,
      );
    }).toList();

    setState(() {
      _interviews = interviews;
      _loading = false;
    });
  }

  bool get _isUpcomingTab => _selectedTab == 'Upcoming';

  List<_InterviewItem> get _filteredInterviews {
    return _interviews.where((i) {
      final matchesTab = _isUpcomingTab ? i.status == 'BOOKED' : i.status != 'BOOKED';
      if (!matchesTab) return false;
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return i.company.toLowerCase().contains(query) || i.role.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final interviews = _filteredInterviews;

    return Scaffold(
      appBar: const CommonHeader(title: 'Interview History'),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.grey.shade50),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
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
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : interviews.isEmpty
                    ? Center(
                        child: Text(
                          _isUpcomingTab ? 'No upcoming interviews.' : 'No completed interviews yet.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadInterviews,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: interviews.length,
                          itemBuilder: (context, index) {
                            final interview = interviews[index];
                            final isCompleted = interview.status != 'BOOKED';
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
                                          child: Text(
                                            interview.company.isNotEmpty ? interview.company[0] : '?',
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(interview.company, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                              if (interview.role.isNotEmpty)
                                                Text(interview.role, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isCompleted ? Colors.green.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            _statusLabel(interview.status),
                                            style: TextStyle(fontSize: 11, color: isCompleted ? Colors.green : Colors.blue, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                                        const SizedBox(width: 4),
                                        Text(_formatDate(interview.slotTime), style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                                        const SizedBox(width: 16),
                                        Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                                        const SizedBox(width: 4),
                                        Text(_formatTime(interview.slotTime), style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                                      ],
                                    ),
                                    if (interview.location.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                                          const SizedBox(width: 4),
                                          Text(interview.location, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          context.push(AppRoutes.interviewRoomFor('AXIS-INT-${interview.id}'));
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF071D43),
                                          foregroundColor: const Color(0xFF27D9D3),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                            side: const BorderSide(color: Color(0xFF27D9D3), width: 1.2),
                                          ),
                                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                                        ),
                                        icon: const Icon(Icons.videocam, size: 18),
                                        label: const Text(
                                          'Join 1-on-1 Interview Room (100ms)',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final instantCode = 'AXIS-MOCK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
          context.push(AppRoutes.interviewRoomFor(instantCode));
        },
        backgroundColor: const Color(0xFF27D9D3),
        foregroundColor: const Color(0xFF071D43),
        icon: const Icon(Icons.video_call, size: 22),
        label: const Text(
          'Instant 1-on-1 Mock Room',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'BOOKED':
        return 'Upcoming';
      case 'COMPLETED':
        return 'Completed';
      case 'CANCELLED':
        return 'Cancelled';
      default:
        return status;
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '-';
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
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
          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade100,
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
  final String role;
  final String location;
  final DateTime? slotTime;
  final String status;

  _InterviewItem({
    required this.id,
    required this.company,
    required this.role,
    required this.location,
    required this.slotTime,
    required this.status,
  });
}
