import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/widgets/common_header.dart';
import '../../../../data/models/exam_model.dart';
import '../browser/in_app_browser_screen.dart';
import '../assessment/assessment_paper_screen.dart';

enum _ExamFilter { pending, graded, upcoming }

class ExamsScreen extends StatefulWidget {
  final int? userId;
  const ExamsScreen({super.key, this.userId});

  @override
  State<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends State<ExamsScreen> {
  List<ExamModel> _all = [];
  bool _loading = true;
  String? _error;
  _ExamFilter _filter = _ExamFilter.upcoming;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<int?> _resolveUserId() async {
    if (widget.userId != null) return widget.userId;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('userId');
  }

  Future<void> _load() async {
    try {
      final api = ApiService();
      final data = await api.getExamsWithStats();
      final raw = (data['exams'] as List?) ?? [];
      final list = raw
          .map((j) => ExamModel.fromJson(j as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() {
          _all = list;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  bool _isGraded(ExamModel e) => e.marksObtained != null || e.isGraded == true;
  bool _isSubmitted(ExamModel e) => e.submissionId != null || e.status == 'Completed';

  int get _pendingCount => _all.where((e) => _isSubmitted(e) && !_isGraded(e)).length;
  int get _gradedCount => _all.where((e) => _isGraded(e)).length;
  int get _upcomingCount => _all.where((e) => !_isSubmitted(e)).length;

  List<ExamModel> get _filtered {
    switch (_filter) {
      case _ExamFilter.graded:
        return _all.where((e) => _isGraded(e)).toList();
      case _ExamFilter.pending:
        return _all.where((e) => _isSubmitted(e) && !_isGraded(e)).toList();
      case _ExamFilter.upcoming:
        return _all.where((e) => !_isSubmitted(e)).toList();
    }
  }
Future<void> _submitExam(ExamModel exam) async {
    try {
      final userId = await _resolveUserId();
      if (userId == null) {
        _showSnack('User ID not found. Please log in again.', Colors.orange);
        return;
      }
      final api = ApiService();
      final success = await api.submitExam(exam.id, userId);
      if (!success) throw Exception('Server rejected the submission');
      _showSnack('Exam submitted successfully', Colors.green);
      _load();
    } catch (e) {
      _showSnack('Failed to submit: $e', Colors.red);
    }
  }

  void _viewDetails(ExamModel exam) {
    final detailsUrl = exam.links?['details'];
    if (detailsUrl == null || detailsUrl.isEmpty) {
      _showSnack('No link available for this exam', Colors.orange);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => InAppBrowserScreen(url: detailsUrl, title: 'Exam Details')),
    );
  }

  /// In-app exams are answered on the paper screen instead of an external link;
  /// the exam duration drives the countdown and the auto-submit.
  Future<void> _openPaper(ExamModel exam) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AssessmentPaperScreen(
          type: 'exams',
          assessmentId: exam.id,
          title: exam.title,
          durationMinutes: exam.durationMinutes,
          totalMarks: exam.totalMarks,
        ),
      ),
    );
    if (result == true) _load();
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonHeader(showBackButton: true, title: 'Exams'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : Column(
                  children: [
                    _buildOverview(),
                    _buildTabs(),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        child: _filtered.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: const [
                                  SizedBox(height: 120),
                                  Center(child: Text('No exams in this category', style: TextStyle(color: Colors.grey))),
                                ],
                              )
                            : ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                                itemCount: _filtered.length,
                                itemBuilder: (context, i) {
                                  final e = _filtered[i];
                                  return _ExamCard(
                                    exam: e,
                                    isGraded: _isGraded(e),
                                    isSubmitted: _isSubmitted(e),
                                    onViewDetails: () => _viewDetails(e),
                                    onSubmit: () => _submitExam(e),
                                    onOpenPaper: () => _openPaper(e),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildOverview() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          _OverviewCard(label: 'Pending', count: _pendingCount, color: const Color(0xFFF59E0B), icon: Icons.hourglass_top),
          const SizedBox(width: 10),
          _OverviewCard(label: 'Graded', count: _gradedCount, color: const Color(0xFF10B981), icon: Icons.check_circle_outline),
          const SizedBox(width: 10),
          _OverviewCard(label: 'Upcoming', count: _upcomingCount, color: const Color(0xFF3B82F6), icon: Icons.event),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(3),
        child: Row(
          children: [
            _buildTab(_ExamFilter.upcoming, 'Upcoming ($_upcomingCount)'),
            _buildTab(_ExamFilter.pending, 'Pending ($_pendingCount)'),
            _buildTab(_ExamFilter.graded, 'Graded ($_gradedCount)'),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(_ExamFilter target, String label) {
    final selected = _filter == target;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filter = target),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2)] : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? const Color(0xFF0F172A) : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }
}
class _OverviewCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _OverviewCard({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
                  ),
                  Text(
                    label,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExamCard extends StatelessWidget {
  final ExamModel exam;
  final bool isGraded;
  final bool isSubmitted;
  final VoidCallback onViewDetails;
  final VoidCallback onSubmit;
  final VoidCallback onOpenPaper;

  const _ExamCard({
    required this.exam,
    required this.isGraded,
    required this.isSubmitted,
    required this.onViewDetails,
    required this.onSubmit,
    required this.onOpenPaper,
  });

  @override
  Widget build(BuildContext context) {
    final secondaryColor = const Color(0xFFEAB308);

    String statusLabel;
    Color statusColor;
    if (isGraded) {
      statusLabel = 'Graded · ${exam.marksObtained ?? 0}/${exam.totalMarks ?? 0}';
      statusColor = const Color(0xFF10B981);
    } else if (isSubmitted) {
      statusLabel = 'Submitted · awaiting grade';
      statusColor = const Color(0xFFF59E0B);
    } else if (exam.status == 'Missed') {
      statusLabel = 'Missed';
      statusColor = const Color(0xFFEF4444);
    } else {
      statusLabel = 'Upcoming';
      statusColor = const Color(0xFF64748B);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    exam.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(statusLabel, style: TextStyle(fontSize: 11, color: statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              exam.description,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(exam.formattedDate, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(exam.durationDisplay, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text('${exam.totalMarks ?? 0} marks', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (exam.isInApp)
              // Answered inside the app: one action, and after submitting it turns
              // into the review of the graded paper.
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onOpenPaper,
                  icon: Icon(isSubmitted ? Icons.fact_check_outlined : Icons.edit_note, size: 19),
                  label: Text(isSubmitted ? 'View Answers' : 'Start Exam'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSubmitted ? const Color(0xFF0F172A) : secondaryColor,
                    foregroundColor: isSubmitted ? Colors.white : Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onViewDetails,
                      icon: Icon(Icons.link, size: 18, color: secondaryColor),
                      label: Text('View Details', style: TextStyle(color: secondaryColor)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!isSubmitted)
                    ElevatedButton.icon(
                      onPressed: onSubmit,
                      icon: const Icon(Icons.upload, size: 18),
                      label: const Text('Submit'),
                      style: ElevatedButton.styleFrom(backgroundColor: secondaryColor, foregroundColor: Colors.black),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}