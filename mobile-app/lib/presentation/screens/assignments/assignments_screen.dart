import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/widgets/common_header.dart';
import '../../../../core/providers/org_theme_provider.dart';
import '../../../../core/widgets/dashboard_glass.dart';
import '../../../../data/models/assignment_model.dart';
import '../browser/in_app_browser_screen.dart';
import '../assessment/assessment_paper_screen.dart';
import '../courses/learning_collection.dart';

enum _AssignFilter { pending, graded, upcoming }

class AssignmentsScreen extends StatefulWidget {
  final int? userId;
  const AssignmentsScreen({super.key, this.userId});

  @override
  State<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends State<AssignmentsScreen> {
  List<AssignmentModel> _all = [];
  bool _loading = true;
  String? _error;
  _AssignFilter _filter = _AssignFilter.upcoming;

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
      final data = await api.getAssignmentsWithStats();
      final raw = (data['assignments'] as List?) ?? [];
      final list = raw
          .map((j) => AssignmentModel.fromJson(j as Map<String, dynamic>))
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

  bool _isGraded(AssignmentModel a) => a.marksObtained != null || a.isGraded == true;
  bool _isSubmitted(AssignmentModel a) => a.submissionId != null || a.status == 'Submitted';

  int get _pendingCount => _all.where((a) => _isSubmitted(a) && !_isGraded(a)).length;
  int get _gradedCount => _all.where((a) => _isGraded(a)).length;
  int get _upcomingCount => _all.where((a) => !_isSubmitted(a)).length;

  List<AssignmentModel> get _filtered {
    switch (_filter) {
      case _AssignFilter.graded:
        return _all.where((a) => _isGraded(a)).toList();
      case _AssignFilter.pending:
        return _all.where((a) => _isSubmitted(a) && !_isGraded(a)).toList();
      case _AssignFilter.upcoming:
        return _all.where((a) => !_isSubmitted(a)).toList();
    }
  }
Future<void> _submitAssignment(AssignmentModel assignment) async {
    try {
      final userId = await _resolveUserId();
      if (userId == null) {
        _showSnack('User ID not found. Please log in again.', Colors.orange);
        return;
      }
      final api = ApiService();
      final success = await api.submitAssignment(assignment.id, userId);
      if (!success) throw Exception('Server rejected the submission');
      _showSnack('Assignment submitted successfully', Colors.green);
      _load();
    } catch (e) {
      _showSnack('Failed to submit: $e', Colors.red);
    }
  }

  void _viewDetails(AssignmentModel assignment) {
    final detailsUrl = assignment.links?['details'];
    if (detailsUrl == null || detailsUrl.isEmpty) {
      _showSnack('No link available for this assignment', Colors.orange);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => InAppBrowserScreen(url: detailsUrl, title: 'Assignment Details')),
    );
  }

  /// In-app assignments are answered on the paper screen instead of an external
  /// link; reload afterwards so the new score shows on the card.
  Future<void> _openPaper(AssignmentModel assignment) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AssessmentPaperScreen(
          type: 'assignments',
          assessmentId: assignment.id,
          title: assignment.title,
          totalMarks: assignment.totalMarks,
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
    return CommonHeaderScaffold(
      subtitle: 'Assignments',
      backgroundColor: const Color(0xFF071D43),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: TextButton(
                    onPressed: _load,
                    child: const Text('Failed to load assignments. Retry'),
                  ),
                )
              : LearningCollection(
                  title: 'My\\nassignments',
                  noun: 'Assignments',
                  onBack: () => Navigator.of(context).maybePop(),
                  onRefresh: _load,
                  entries: _all.map((assignment) {
                    final graded = _isGraded(assignment);
                    final submitted = _isSubmitted(assignment);
                    return LearningEntry(
                      id: assignment.id,
                      title: assignment.title,
                      label: 'Assignment',
                      completed: graded,
                      progress: graded ? 1 : submitted ? .65 : 0,
                      detail: graded
                          ? 'Graded · ${assignment.marksObtained ?? 0}/${assignment.totalMarks ?? 0} marks'
                          : submitted
                              ? 'Submitted · awaiting grade'
                              : assignment.isOverdue
                                  ? 'Overdue · ${assignment.totalMarks ?? 0} marks'
                                  : 'Due ${assignment.formattedDueDate} · ${assignment.totalMarks ?? 0} marks',
                      onOpen: () {
                        if (assignment.isInApp) {
                          _openPaper(assignment);
                        } else if (submitted) {
                          _viewDetails(assignment);
                        } else {
                          _submitAssignment(assignment);
                        }
                      },
                    );
                  }).toList(),
                ),
    );
  }
Widget _buildOverview(dynamic theme) {
  return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          _OverviewCard(label: 'Pending', count: _pendingCount, color: theme.secondary, icon: Icons.hourglass_top),
          const SizedBox(width: 10),
          _OverviewCard(label: 'Graded', count: _gradedCount, color: theme.tertiary, icon: Icons.check_circle_outline),
          const SizedBox(width: 10),
          _OverviewCard(label: 'Upcoming', count: _upcomingCount, color: theme.primary, icon: Icons.event),
        ],
      ),
    );
  }

  Widget _buildTabs(dynamic theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: theme.surface.withOpacity(.82),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(3),
        child: Row(
          children: [
            _buildTab(_AssignFilter.upcoming, 'Upcoming ($_upcomingCount)', theme),
            _buildTab(_AssignFilter.pending, 'Pending ($_pendingCount)', theme),
            _buildTab(_AssignFilter.graded, 'Graded ($_gradedCount)', theme),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(_AssignFilter target, String label, ColorScheme theme) {
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
              color: selected ? theme.primary : theme.onSurfaceVariant,
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

class _AssignmentCard extends StatelessWidget {
  final AssignmentModel assignment;
  final bool isGraded;
  final bool isSubmitted;
  final VoidCallback onViewDetails;
  final VoidCallback onSubmit;
  final VoidCallback onOpenPaper;

  const _AssignmentCard({
    required this.assignment,
    required this.isGraded,
    required this.isSubmitted,
    required this.onViewDetails,
    required this.onSubmit,
    required this.onOpenPaper,
  });

  @override
  Widget build(BuildContext context) {
    String statusLabel;
    Color statusColor;
    if (isGraded) {
      statusLabel = 'Graded · ${assignment.marksObtained ?? 0}/${assignment.totalMarks ?? 0}';
      statusColor = const Color(0xFF10B981);
    } else if (isSubmitted) {
      statusLabel = 'Submitted · awaiting grade';
      statusColor = const Color(0xFFF59E0B);
    } else if (assignment.isOverdue) {
      statusLabel = 'Overdue';
      statusColor = const Color(0xFFEF4444);
    } else {
      statusLabel = 'Pending';
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
                    assignment.title,
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
              assignment.description,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(assignment.formattedDueDate, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(width: 16),
                Icon(Icons.star, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text('${assignment.totalMarks ?? 0} marks', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(height: 12),
            if (assignment.isInApp)
              // Answered inside the app: one action, and after submitting it turns
              // into the review of the graded paper.
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onOpenPaper,
                  icon: Icon(isSubmitted ? Icons.fact_check_outlined : Icons.edit_note, size: 19),
                  label: Text(isSubmitted ? 'View Answers' : 'Start Paper'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSubmitted ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondary,
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
                      icon: Icon(Icons.link, size: 18, color: Theme.of(context).colorScheme.secondary),
                      label: Text('View Details', style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!isSubmitted)
                    ElevatedButton.icon(
                      onPressed: onSubmit,
                      icon: const Icon(Icons.upload, size: 18),
                      label: const Text('Submit'),
                      style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.secondary, foregroundColor: Colors.black),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}


