import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/common_header.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final ApiService _api = ApiService();

  // Tab: 0 = Interview Evaluations, 1 = Submit App Feedback
  int _activeTab = 0;

  // Interview Feedbacks state
  bool _loadingInterviews = true;
  List<Map<String, dynamic>> _interviewFeedbacks = [];

  // General App Feedback state
  String _selectedType = 'General';
  final TextEditingController _feedbackController = TextEditingController();
  int _rating = 0;
  bool _submitting = false;
  List<Map<String, dynamic>> _myFeedback = [];
  bool _loadingMyFeedback = true;

  @override
  void initState() {
    super.initState();
    _loadInterviewFeedbacks();
    _loadMyFeedback();
  }

  Future<void> _loadInterviewFeedbacks() async {
    setState(() => _loadingInterviews = true);
    final list = await _api.getInterviewFeedbacks();
    if (!mounted) return;
    setState(() {
      _interviewFeedbacks = list;
      _loadingInterviews = false;
    });
  }

  Future<void> _loadMyFeedback() async {
    final feedback = await _api.getMyFeedback();
    if (!mounted) return;
    setState(() {
      _myFeedback = feedback;
      _loadingMyFeedback = false;
    });
  }

  Future<void> _handleSubmit() async {
    if (_feedbackController.text.trim().isEmpty || _rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide rating and feedback')),
      );
      return;
    }

    setState(() => _submitting = true);
    final success = await _api.submitFeedback(
      type: _selectedType,
      rating: _rating,
      comment: _feedbackController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thank you for your feedback!')),
      );
      _feedbackController.clear();
      setState(() {
        _rating = 0;
        _selectedType = 'General';
      });
      _loadMyFeedback();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit feedback. Please try again.')),
      );
    }
  }

  void _showRubricDetailModal(Map<String, dynamic> item) {
    final title = (item['title'] as String?) ?? '1-on-1 Technical Round';
    final company = (item['companyName'] as String?) ?? '';
    final role = (item['driveRole'] as String?) ?? '';
    final interviewer = (item['interviewerName'] as String?) ?? 'Faculty Interviewer';
    final interviewerEmail = (item['interviewerEmail'] as String?) ?? '';
    final date = (item['endedAt'] ?? item['scheduledAt'] ?? item['startedAt'] ?? '') as String;
    final decision = (item['hiringDecision'] as String?) ?? 'PENDING';
    final notes = (item['interviewerNotes'] as String?) ?? '';
    final submittedCode = (item['submittedCode'] as String?) ?? '';

    final pScore = (item['problemSolvingScore'] as num?)?.toInt() ?? 0;
    final tScore = (item['technicalCompetencyScore'] as num?)?.toInt() ?? 0;
    final cScore = (item['codeQualityScore'] as num?)?.toInt() ?? 0;
    final mScore = (item['communicationScore'] as num?)?.toInt() ?? 0;
    final double overall = (pScore + tScore + cScore + mScore) / 4.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF071120),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.88,
          child: Column(
            children: [
              // Bottom sheet handle & top header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF111E33),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.rate_review, color: Color(0xFF27D9D3), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Interviewer Rubric Evaluation',
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
                            '${overall.toStringAsFixed(1)} / 5.0',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF27D9D3),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),

              // Scrollable Evaluation Content (Exact Rubric Card Layout)
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Interview Info Banner
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
                              radius: 20,
                              backgroundColor: const Color(0xFF27D9D3).withOpacity(0.2),
                              child: const Icon(Icons.school, color: Color(0xFF27D9D3), size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                                  ),
                                  if (company.isNotEmpty)
                                    Text(
                                      '🏢 $company ${role.isNotEmpty ? "($role)" : ""}',
                                      style: GoogleFonts.inter(color: const Color(0xFF27D9D3), fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  Text(
                                    'Faculty Interviewer: $interviewer ${interviewerEmail.isNotEmpty ? "($interviewerEmail)" : ""}',
                                    style: GoogleFonts.inter(color: Colors.white60, fontSize: 11),
                                  ),
                                  if (date.isNotEmpty)
                                    Text(
                                      'Conducted: ${_formatDate(date)}',
                                      style: GoogleFonts.inter(color: Colors.white38, fontSize: 10.5),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Rubric Scores Section
                      Text(
                        'STRUCTURED RUBRIC SCORES',
                        style: GoogleFonts.inter(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 10),

                      _buildRubricRatingRow(
                        title: 'Problem Solving & DSA',
                        description: 'Understanding constraints, algorithmic complexity, optimal data structures',
                        value: pScore,
                      ),

                      _buildRubricRatingRow(
                        title: 'Technical & Language Proficiency',
                        description: 'Idiomatic syntax, memory awareness, standard library usage',
                        value: tScore,
                      ),

                      _buildRubricRatingRow(
                        title: 'Code Quality & Clean Architecture',
                        description: 'Modular breakdown, variable naming, defensive edge cases',
                        value: cScore,
                      ),

                      _buildRubricRatingRow(
                        title: 'Communication & Articulation',
                        description: 'Thinking out loud, clarifying ambiguity, handling hints',
                        value: mScore,
                      ),

                      const SizedBox(height: 14),

                      // Hiring Decision Recommendation
                      Text(
                        'Faculty Hiring Recommendation',
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _getDecisionColor(decision).withOpacity(0.18),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _getDecisionColor(decision).withOpacity(0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_rounded, color: _getDecisionColor(decision), size: 16),
                            const SizedBox(width: 8),
                            Text(
                              _formatDecision(decision),
                              style: GoogleFonts.inter(
                                color: _getDecisionColor(decision),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Interviewer Notes
                      Text(
                        'Interviewer Detailed Notes & Feedback',
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F1A2E),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Text(
                          notes.isNotEmpty
                              ? notes
                              : 'No written comments provided by faculty interviewer.',
                          style: GoogleFonts.inter(
                            color: notes.isNotEmpty ? const Color(0xFFCBD5E1) : Colors.white38,
                            fontSize: 12.5,
                            height: 1.5,
                          ),
                        ),
                      ),

                      // Submitted Code snippet if present
                      if (submittedCode.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Text(
                          'Submitted Code in Studio',
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A0F1D),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Text(
                              submittedCode,
                              style: GoogleFonts.firaCode(color: const Color(0xFF27D9D3), fontSize: 11.5, height: 1.4),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRubricRatingRow({
    required String title,
    required String description,
    required int value,
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
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Icon(
                      filled ? Icons.star : Icons.star_border,
                      color: filled ? const Color(0xFFFBBF24) : Colors.white24,
                      size: 18,
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primaryColor = cs.primary;

    return Scaffold(
      backgroundColor: const Color(0xFF070F1D),
      appBar: const CommonHeader(title: 'Feedback'),
      body: Column(
        children: [
          // Segmented Tabs Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1A2E),
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _activeTab = 0),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _activeTab == 0 ? const Color(0xFF27D9D3).withOpacity(0.18) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: _activeTab == 0 ? Border.all(color: const Color(0xFF27D9D3).withOpacity(0.4)) : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.rate_review_rounded, size: 15, color: _activeTab == 0 ? const Color(0xFF27D9D3) : Colors.white60),
                          const SizedBox(width: 6),
                          Text(
                            'Interview Evaluations',
                            style: GoogleFonts.inter(
                              color: _activeTab == 0 ? const Color(0xFF27D9D3) : Colors.white60,
                              fontSize: 12.5,
                              fontWeight: _activeTab == 0 ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _activeTab = 1),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _activeTab == 1 ? const Color(0xFF27D9D3).withOpacity(0.18) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: _activeTab == 1 ? Border.all(color: const Color(0xFF27D9D3).withOpacity(0.4)) : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.feedback_outlined, size: 15, color: _activeTab == 1 ? const Color(0xFF27D9D3) : Colors.white60),
                          const SizedBox(width: 6),
                          Text(
                            'Submit App Feedback',
                            style: GoogleFonts.inter(
                              color: _activeTab == 1 ? const Color(0xFF27D9D3) : Colors.white60,
                              fontSize: 12.5,
                              fontWeight: _activeTab == 1 ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tab View
          Expanded(
            child: _activeTab == 0 ? _buildInterviewFeedbacksView() : _buildGeneralFeedbackView(primaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildInterviewFeedbacksView() {
    if (_loadingInterviews) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF27D9D3)),
      );
    }

    if (_interviewFeedbacks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.rate_review_outlined, color: Colors.white24, size: 54),
              const SizedBox(height: 14),
              Text(
                'No Interview Evaluations Yet',
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Once your faculty conducts and submits your 1-on-1 mock interview evaluation, your full rubric score card will appear here.',
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadInterviewFeedbacks,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF27D9D3),
                  foregroundColor: const Color(0xFF04101E),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInterviewFeedbacks,
      color: const Color(0xFF27D9D3),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _interviewFeedbacks.length,
        itemBuilder: (context, index) {
          final item = _interviewFeedbacks[index];
          final title = (item['title'] as String?) ?? 'Technical Mock Interview';
          final company = (item['companyName'] as String?) ?? '';
          final role = (item['driveRole'] as String?) ?? '';
          final interviewer = (item['interviewerName'] as String?) ?? 'Faculty Interviewer';
          final date = (item['endedAt'] ?? item['scheduledAt'] ?? item['startedAt'] ?? '') as String;
          final decision = (item['hiringDecision'] as String?) ?? 'HIRE';
          final pScore = (item['problemSolvingScore'] as num?)?.toInt() ?? 0;
          final tScore = (item['technicalCompetencyScore'] as num?)?.toInt() ?? 0;
          final cScore = (item['codeQualityScore'] as num?)?.toInt() ?? 0;
          final mScore = (item['communicationScore'] as num?)?.toInt() ?? 0;
          final double overall = (pScore + tScore + cScore + mScore) / 4.0;

          return Card(
            color: const Color(0xFF0F1A2E),
            margin: const EdgeInsets.only(bottom: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
            child: InkWell(
              onTap: () => _showRubricDetailModal(item),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Row: Title + Decision Badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              if (company.isNotEmpty)
                                Text(
                                  '🏢 $company ${role.isNotEmpty ? "($role)" : ""}',
                                  style: GoogleFonts.inter(color: const Color(0xFF27D9D3), fontSize: 11.5, fontWeight: FontWeight.w600),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getDecisionColor(decision).withOpacity(0.18),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _getDecisionColor(decision).withOpacity(0.4)),
                          ),
                          child: Text(
                            _formatDecision(decision),
                            style: GoogleFonts.inter(
                              color: _getDecisionColor(decision),
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Faculty details & date
                    Row(
                      children: [
                        const Icon(Icons.person_pin, size: 14, color: Colors.white60),
                        const SizedBox(width: 4),
                        Text(
                          interviewer,
                          style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.calendar_today, size: 12, color: Colors.white38),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(date),
                          style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    Divider(color: Colors.white.withOpacity(0.06), height: 1),
                    const SizedBox(height: 10),

                    // Rubric Score Badges + Tap prompt
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF27D9D3).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, color: Color(0xFF27D9D3), size: 13),
                              const SizedBox(width: 4),
                              Text(
                                '${overall.toStringAsFixed(1)} / 5.0',
                                style: GoogleFonts.inter(color: const Color(0xFF27D9D3), fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Text(
                              'View Rubric Card',
                              style: GoogleFonts.inter(color: const Color(0xFF818CF8), fontSize: 11.5, fontWeight: FontWeight.w600),
                            ),
                            const Icon(Icons.chevron_right, color: Color(0xFF818CF8), size: 16),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGeneralFeedbackView(Color primaryColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: const Color(0xFF0F1A2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Submit App & Platform Feedback',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                  ),
                  const SizedBox(height: 16),
                  const Text('Feedback Type', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.white70)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['General', 'Bug', 'Feature', 'Course', 'Instructor'].map((type) {
                      final isSelected = _selectedType == type;
                      return ChoiceChip(
                        label: Text(type),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _selectedType = type),
                        selectedColor: const Color(0xFF27D9D3),
                        labelStyle: TextStyle(color: isSelected ? Colors.black : Colors.white70),
                        backgroundColor: const Color(0xFF13223A),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text('Your Rating', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.white70)),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(5, (index) {
                      return IconButton(
                        onPressed: () => setState(() => _rating = index + 1),
                        icon: Icon(
                          index < _rating ? Icons.star : Icons.star_border,
                          color: const Color(0xFFFBBF24),
                          size: 30,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  const Text('Your Feedback', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.white70)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _feedbackController,
                    maxLines: 5,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Tell us your suggestions, thoughts or bug reports...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF13223A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF27D9D3),
                        foregroundColor: const Color(0xFF04101E),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Text('Submit Feedback', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Your Past Submissions',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
          ),
          const SizedBox(height: 12),
          if (_loadingMyFeedback)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(color: Color(0xFF27D9D3))),
            )
          else if (_myFeedback.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'You haven\'t submitted any general feedback yet.',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _myFeedback.length,
              itemBuilder: (context, index) {
                final item = _myFeedback[index];
                final rating = (item['rating'] as num?)?.toInt() ?? 0;
                final type = (item['type'] as String?) ?? 'General';
                final comment = (item['comment'] as String?) ?? '';
                final createdAt = (item['createdAt'] as String?) ?? '';
                return Card(
                  color: const Color(0xFF0F1A2E),
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF27D9D3).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(type, style: const TextStyle(fontSize: 11, color: Color(0xFF27D9D3), fontWeight: FontWeight.bold)),
                            ),
                            if (createdAt.isNotEmpty)
                              Text(createdAt, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: List.generate(5, (i) {
                            return Icon(Icons.star, size: 15, color: i < rating ? const Color(0xFFFBBF24) : Colors.white24);
                          }),
                        ),
                        if (comment.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(comment, style: const TextStyle(fontSize: 12.5, color: Colors.white70)),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    if (iso.isEmpty) return 'Recent';
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  String _formatDecision(String decision) {
    switch (decision.toUpperCase()) {
      case 'STRONG_HIRE':
        return 'Strong Hire';
      case 'HIRE':
        return 'Hire';
      case 'LEAN_HIRE':
        return 'Lean Hire';
      case 'LEAN_REJECT':
        return 'Lean Reject';
      case 'REJECT':
        return 'Reject';
      default:
        return decision;
    }
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