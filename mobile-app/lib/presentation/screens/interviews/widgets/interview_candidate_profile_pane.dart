import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/api_service.dart';

class InterviewCandidateProfilePane extends StatefulWidget {
  final int? candidateId;
  final String? candidateName;
  final String? candidateEmail;
  final String? batchName;

  const InterviewCandidateProfilePane({
    super.key,
    this.candidateId,
    this.candidateName,
    this.candidateEmail,
    this.batchName,
  });

  @override
  State<InterviewCandidateProfilePane> createState() => _InterviewCandidateProfilePaneState();
}

class _InterviewCandidateProfilePaneState extends State<InterviewCandidateProfilePane> {
  final ApiService _api = ApiService();
  bool _loading = true;
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  @override
  void didUpdateWidget(covariant InterviewCandidateProfilePane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.candidateId != oldWidget.candidateId) {
      _fetchStats();
    }
  }

  Future<void> _fetchStats() async {
    final cId = widget.candidateId;
    if (cId == null || cId == 0) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (mounted) setState(() => _loading = true);
    final res = await _api.getStudentStats(cId);
    if (!mounted) return;
    setState(() {
      _stats = res;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final candidateName = widget.candidateName ??
        (_stats?['student']?['name'] as String?) ??
        'Candidate Student';
    final candidateEmail = widget.candidateEmail ??
        (_stats?['student']?['email'] as String?) ??
        'candidate@axisora.internal';
    final candidatePhone = (_stats?['student']?['phone'] as String?) ?? 'Not provided';
    final batchName = widget.batchName ??
        (_stats?['student']?['batchName'] as String?) ??
        'Full Stack Batch';
    final planName = (_stats?['student']?['planName'] as String?) ?? '';

    final attendance = _stats?['attendance'] as Map<String, dynamic>?;
    final assignments = _stats?['assignments'] as Map<String, dynamic>?;
    final exams = _stats?['exams'] as Map<String, dynamic>?;
    final courses = _stats?['courses'] as Map<String, dynamic>?;
    final placements = _stats?['placements'] as Map<String, dynamic>?;
    final feedbacks = _stats?['feedbacks'] as Map<String, dynamic>?;
    final feedbackRecords = (_stats?['feedbackRecords'] as List<dynamic>?) ?? [];

    return Container(
      color: const Color(0xFF071120),
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1A2E),
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_pin_rounded, color: Color(0xFF27D9D3), size: 18),
                const SizedBox(width: 8),
                Text(
                  'Candidate Profile & Records',
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (widget.candidateId != null)
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 16, color: Colors.white70),
                    onPressed: () {
                      setState(() => _loading = true);
                      _fetchStats();
                    },
                  ),
              ],
            ),
          ),

          if (_loading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF27D9D3)),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Candidate Top Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1A2E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: const Color(0xFF27D9D3).withOpacity(0.2),
                            child: Text(
                              candidateName.isNotEmpty ? candidateName[0].toUpperCase() : 'C',
                              style: GoogleFonts.outfit(color: const Color(0xFF27D9D3), fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  candidateName,
                                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  candidateEmail,
                                  style: GoogleFonts.inter(color: Colors.white60, fontSize: 12),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF6366F1).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '👥 $batchName',
                                        style: GoogleFonts.inter(color: const Color(0xFFA5B4FC), fontSize: 10.5, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    if (planName.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF59E0B).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '⭐ $planName',
                                          style: GoogleFonts.inter(color: const Color(0xFFFBBF24), fontSize: 10.5, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Metrics Grid (matches Admin Student Detail)
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.55,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildMetricTile(
                          title: 'Attendance',
                          value: '${attendance?['percentage'] ?? 0}%',
                          subtitle: '${attendance?['attended'] ?? 0} / ${attendance?['totalClasses'] ?? 0} classes',
                          color: const Color(0xFF10B981),
                          icon: Icons.calendar_today,
                        ),
                        _buildMetricTile(
                          title: 'Assignments',
                          value: '${assignments?['submissionPercentage'] ?? 0}%',
                          subtitle: 'Avg Marks: ${assignments?['averageMarks'] ?? 0}',
                          color: const Color(0xFF6366F1),
                          icon: Icons.assignment_outlined,
                        ),
                        _buildMetricTile(
                          title: 'Exams Pass Rate',
                          value: '${exams?['passPercentage'] ?? 0}%',
                          subtitle: '${exams?['passed'] ?? 0} Passed · ${exams?['failed'] ?? 0} Failed',
                          color: const Color(0xFF27D9D3),
                          icon: Icons.quiz_outlined,
                        ),
                        _buildMetricTile(
                          title: 'Total Feedbacks',
                          value: '${feedbacks?['totalFeedbacks'] ?? 0}',
                          subtitle: '${feedbacks?['recommendedHires'] ?? 0} Recommended Hires',
                          color: const Color(0xFFF59E0B),
                          icon: Icons.rate_review_outlined,
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Previous Evaluations & Rubric History
                    Text(
                      'PREVIOUS INTERVIEW EVALUATIONS',
                      style: GoogleFonts.inter(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 8),

                    if (feedbackRecords.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F1A2E),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withOpacity(0.06)),
                        ),
                        child: Center(
                          child: Text(
                            'No previous 1-on-1 interview evaluations on record.',
                            style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                          ),
                        ),
                      )
                    else
                      ...feedbackRecords.map((fb) {
                        final decision = (fb['hiringDecision'] as String?) ?? 'HIRE';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F1A2E),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withOpacity(0.06)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      (fb['title'] as String?) ?? 'Technical Mock Interview',
                                      style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _getDecisionColor(decision).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      decision.replaceAll('_', ' '),
                                      style: GoogleFonts.inter(
                                        color: _getDecisionColor(decision),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Interviewer: ${fb['interviewerName'] ?? 'Faculty'} · ${fb['interviewDate'] ?? 'Recent'}',
                                style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  _scoreBadge('Problem Solving', fb['problemSolvingScore']),
                                  const SizedBox(width: 6),
                                  _scoreBadge('Technical', fb['technicalCompetencyScore']),
                                  const SizedBox(width: 6),
                                  _scoreBadge('Code Quality', fb['codeQualityScore']),
                                  const SizedBox(width: 6),
                                  _scoreBadge('Comm', fb['communicationScore']),
                                ],
                              ),
                              if (fb['interviewerNotes'] != null && (fb['interviewerNotes'] as String).isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  '"${fb['interviewerNotes']}"',
                                  style: GoogleFonts.inter(color: const Color(0xFFCBD5E1), fontSize: 11, fontStyle: FontStyle.italic),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1A2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.inter(color: Colors.white38, fontSize: 10),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _scoreBadge(String label, dynamic score) {
    final s = score != null ? '$score/5' : '-';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF13223A),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label: $s',
        style: GoogleFonts.inter(color: const Color(0xFF27D9D3), fontSize: 9.5, fontWeight: FontWeight.w500),
      ),
    );
  }

  Color _getDecisionColor(String decision) {
    switch (decision.toUpperCase()) {
      case 'STRONG_HIRE':
      case 'HIRE':
        return const Color(0xFF10B981);
      case 'LEAN_HIRE':
        return const Color(0xFFF59E0B);
      case 'LEAN_REJECT':
      case 'REJECT':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF27D9D3);
    }
  }
}
