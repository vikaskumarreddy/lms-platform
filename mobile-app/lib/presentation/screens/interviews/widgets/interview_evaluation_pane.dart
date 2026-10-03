import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Interviewer Rubric & Private Evaluation Sheet.
/// Allows mentors and technical interviewers to score candidates on
/// Problem Solving, Technical Competency, Code Quality, Communication,
/// select a final Hiring Decision, and write private notes.
class InterviewEvaluationPane extends StatefulWidget {
  final String roomCode;
  final String? candidateName;
  final int initialProblemSolving;
  final int initialTechnical;
  final int initialCodeQuality;
  final int initialCommunication;
  final String initialDecision;
  final String initialNotes;
  final Future<bool> Function(Map<String, dynamic> eval) onSubmit;

  const InterviewEvaluationPane({
    super.key,
    required this.roomCode,
    this.candidateName,
    this.initialProblemSolving = 4,
    this.initialTechnical = 4,
    this.initialCodeQuality = 3,
    this.initialCommunication = 4,
    this.initialDecision = 'HIRE',
    this.initialNotes = '',
    required this.onSubmit,
  });

  @override
  State<InterviewEvaluationPane> createState() => _InterviewEvaluationPaneState();
}

class _InterviewEvaluationPaneState extends State<InterviewEvaluationPane> {
  late int _problemSolving;
  late int _technical;
  late int _codeQuality;
  late int _communication;
  late String _hiringDecision;
  late TextEditingController _notesController;
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _decisions = [
    {'code': 'STRONG_HIRE', 'label': 'Strong Hire', 'color': Color(0xFF10B981)},
    {'code': 'HIRE', 'label': 'Hire', 'color': Color(0xFF3B82F6)},
    {'code': 'LEAN_HIRE', 'label': 'Lean Hire', 'color': Color(0xFF06B6D4)},
    {'code': 'LEAN_REJECT', 'label': 'Lean Reject', 'color': Color(0xFFF59E0B)},
    {'code': 'REJECT', 'label': 'Reject', 'color': Color(0xFFEF4444)},
  ];

  @override
  void initState() {
    super.initState();
    _problemSolving = widget.initialProblemSolving;
    _technical = widget.initialTechnical;
    _codeQuality = widget.initialCodeQuality;
    _communication = widget.initialCommunication;
    _hiringDecision = widget.initialDecision.isNotEmpty ? widget.initialDecision : 'HIRE';
    _notesController = TextEditingController(text: widget.initialNotes);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  double get _overallScore {
    return (_problemSolving + _technical + _codeQuality + _communication) / 4.0;
  }

  Future<void> _handleSubmit({bool finalize = false}) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final payload = {
      'problemSolvingScore': _problemSolving,
      'technicalCompetencyScore': _technical,
      'codeQualityScore': _codeQuality,
      'communicationScore': _communication,
      'hiringDecision': _hiringDecision,
      'interviewerNotes': _notesController.text,
      'finalize': finalize,
    };

    final ok = await widget.onSubmit(payload);
    if (mounted) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok ? 'Evaluation submitted successfully!' : 'Failed to save evaluation.',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: ok ? const Color(0xFF10B981) : Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1726),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Evaluation Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF111E33),
                border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.rate_review, color: Color(0xFF27D9D3), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Interviewer Rubric',
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  // Overall Score Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF27D9D3).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF27D9D3).withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: Color(0xFF27D9D3), size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${_overallScore.toStringAsFixed(1)} / 5.0',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF27D9D3),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Rubric Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Candidate Info Banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16233B),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFF27D9D3).withOpacity(0.2),
                            child: const Icon(Icons.person, color: Color(0xFF27D9D3), size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.candidateName ?? 'Candidate',
                                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Text(
                                  'Private notes & rubric are visible to interviewers only.',
                                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 10.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Rubric Sliders
                    _buildRubricRatingRow(
                      title: 'Problem Solving & DSA',
                      description: 'Understanding constraints, algorithmic complexity, optimal data structures',
                      value: _problemSolving,
                      onChanged: (v) => setState(() => _problemSolving = v),
                    ),

                    _buildRubricRatingRow(
                      title: 'Technical & Language Proficiency',
                      description: 'Idiomatic syntax, memory awareness, standard library usage',
                      value: _technical,
                      onChanged: (v) => setState(() => _technical = v),
                    ),

                    _buildRubricRatingRow(
                      title: 'Code Quality & Clean Architecture',
                      description: 'Modular breakdown, variable naming, defensive edge cases',
                      value: _codeQuality,
                      onChanged: (v) => setState(() => _codeQuality = v),
                    ),

                    _buildRubricRatingRow(
                      title: 'Communication & Articulation',
                      description: 'Thinking out loud, clarifying ambiguity, handling hints',
                      value: _communication,
                      onChanged: (v) => setState(() => _communication = v),
                    ),

                    const SizedBox(height: 14),

                    // Hiring Decision Selector
                    Text(
                      'Hiring Recommendation',
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _decisions.map((d) {
                        final isSelected = _hiringDecision == d['code'];
                        final color = d['color'] as Color;
                        return InkWell(
                          onTap: () => setState(() => _hiringDecision = d['code'] as String),
                          borderRadius: BorderRadius.circular(8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? color.withOpacity(0.2) : const Color(0xFF16233B),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? color : Colors.white.withOpacity(0.08),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Text(
                              d['label'] as String,
                              style: GoogleFonts.inter(
                                color: isSelected ? color : Colors.white70,
                                fontSize: 11.5,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 18),

                    // Private Notes Field
                    Text(
                      'Interviewer Notes & Feedback',
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1B2E),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: TextField(
                        controller: _notesController,
                        maxLines: 4,
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 12.5),
                        decoration: InputDecoration(
                          hintText: 'Record key strengths, areas for improvement, and round summary...',
                          hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 12),
                          contentPadding: const EdgeInsets.all(12),
                          filled: true,
                          fillColor: const Color(0xFF0F1B2E),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isSubmitting ? null : () => _handleSubmit(finalize: false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF27D9D3),
                              side: const BorderSide(color: Color(0xFF27D9D3)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.save, size: 16),
                            label: Text(
                              'Save Draft',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isSubmitting ? null : () => _handleSubmit(finalize: true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: _isSubmitting
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.check_circle, size: 16),
                            label: Text(
                              'Finalize & Complete',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRubricRatingRow({
    required String title,
    required String description,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  final starNum = index + 1;
                  final filled = starNum <= value;
                  return InkWell(
                    onTap: () => onChanged(starNum),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Icon(
                        filled ? Icons.star : Icons.star_border,
                        color: filled ? const Color(0xFFFBBF24) : Colors.white24,
                        size: 20,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: GoogleFonts.inter(color: Colors.white38, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}
