import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/widgets/common_header.dart';
import '../../../core/services/api_service.dart';
import '../../../data/models/question_model.dart';

class QaScreen extends ConsumerStatefulWidget {
  const QaScreen({super.key});
  @override
  ConsumerState<QaScreen> createState() => _QaScreenState();
}

class _QaScreenState extends ConsumerState<QaScreen> {
  String _selectedFilter = 'All';
  final _questionController = TextEditingController();
  final _titleController = TextEditingController();
  final _categoryController = TextEditingController();
  bool _showAskForm = false;
  bool _isLoading = true;
  bool _isSubmitting = false;
  List<QuestionModel> _questions = [];
  int _dailyRemaining = 10;
  bool _canAsk = true;

  final List<String> _filters = ['All', 'Java', 'SQL', 'DSA', 'Web', 'Coding'];

  static const _bgDark = Color(0xFF071D43);
  static const _cardDark = Color(0xFF0C2B64);
  static const _cyan = Color(0xFF27D9D3);
  static const _green = Color(0xFF10B981);
  static const _amber = Color(0xFFF59E0B);

  @override
  void initState() {
    super.initState();
    _loadQuestions();
    _loadDailyStatus();
  }

  Future<void> _loadDailyStatus() async {
    try {
      final res = await ApiService().get('/api/questions/daily-status');
      if (res != null && mounted) {
        setState(() {
          _dailyRemaining = res['remaining'] ?? 10;
          _canAsk = res['canAsk'] ?? true;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadQuestions() async {
    try {
      final questions = await ApiService().getQuestions();
      if (!mounted) return;
      setState(() {
        _questions = questions;
        final backendCategories =
            questions.map((q) => q.category).toSet().toList();
        for (final cat in backendCategories) {
          if (cat.isNotEmpty && !_filters.contains(cat)) {
            _filters.add(cat);
          }
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<QuestionModel> get _filteredQuestions {
    if (_selectedFilter == 'All') return _questions;
    return _questions.where((q) => q.category == _selectedFilter).toList();
  }

  @override
  void dispose() {
    _questionController.dispose();
    _titleController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  String _formatTimeAgo(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return 'Recently';
    final date = DateTime.tryParse(isoDate);
    if (date == null) return 'Recently';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 2) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.year}/${date.month}/${date.day}';
  }

  Color _categoryColor(String category) {
    final colors = <Color>[
      const Color(0xFF38BDF8),
      const Color(0xFF10B981),
      const Color(0xFF9B5CFF),
      const Color(0xFF27D9D3),
      const Color(0xFFF59E0B),
      const Color(0xFFEC4899),
    ];
    return colors[category.hashCode.abs() % colors.length];
  }

  String _authorInitial(String authorName) {
    if (authorName.isEmpty) return '?';
    return authorName[0].toUpperCase();
  }

  Future<void> _submitQuestion() async {
    if (!_canAsk) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Daily limit of 10 doubts reached. Try again tomorrow or escalate existing questions!'),
          backgroundColor: Color(0xFFF59E0B),
        ),
      );
      return;
    }

    final text = _questionController.text.trim();
    final title = _titleController.text.trim();
    final category = _categoryController.text.trim().isEmpty
        ? 'General'
        : _categoryController.text.trim();
    if (text.isEmpty || title.isEmpty) return;

    setState(() => _isSubmitting = true);
    final result = await ApiService().createQuestion(
      title: title,
      content: text,
      category: category,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result != null) {
      _questionController.clear();
      _titleController.clear();
      _categoryController.clear();
      setState(() => _showAskForm = false);
      _loadQuestions();
      _loadDailyStatus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Doubt posted! AI Assistant is reviewing your question.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to post question. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showQuestionDetails(QuestionModel qa) {
    final authorColor = _categoryColor(qa.category);
    final answerCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: const Color(0xFF092350),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        List<AnswerModel> answers = [];
        bool loadingAnswers = true;
        bool submittingAnswer = false;
        bool hasFetched = false;
        bool isEscalated = qa.isEscalated;
        bool isEscalating = false;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            // Fetch answers only once on first build
            if (!hasFetched) {
              hasFetched = true;
              ApiService().getAnswersByQuestion(qa.id).then((fetched) {
                setSheetState(() {
                  answers = fetched;
                  loadingAnswers = false;
                });
              });
            }

            final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
            final systemBottom = MediaQuery.of(ctx).padding.bottom;
            final isHidden = ref.read(shellNavBarHiddenProvider);
            final safeBottom = bottomInset > 0
                ? bottomInset + 16
                : math.max(systemBottom + 20, isHidden ? 28.0 : 110.0);

            return SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, safeBottom),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: authorColor.withOpacity(0.25),
                          child: Text(
                            _authorInitial(qa.authorName),
                            style: TextStyle(
                              color: authorColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                qa.authorName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatTimeAgo(qa.createdAt),
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: authorColor.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: authorColor.withOpacity(0.4)),
                          ),
                          child: Text(
                            qa.category,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: authorColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      qa.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (qa.content.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        qa.content,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13.5,
                          height: 1.45,
                        ),
                      ),
                    ],
                    const Divider(color: Colors.white12, height: 28),
                    Row(
                      children: [
                        Icon(
                          qa.isAnswered ? Icons.check_circle : Icons.hourglass_empty,
                          size: 15,
                          color: qa.isAnswered ? _green : _amber,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${answers.length} ${answers.length == 1 ? "Answer" : "Answers"}',
                          style: TextStyle(
                            color: qa.isAnswered ? _green : _amber,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Answer list
                    if (loadingAnswers)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF27D9D3),
                            ),
                          ),
                        ),
                      )
                    else if (answers.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: Text(
                            'No answers yet. Be the first to answer!',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.45),
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      )
                    else
                      ...answers.map((answer) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0C2B64).withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: answer.isAccepted
                                ? _green.withOpacity(0.5)
                                : Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 13,
                                  backgroundColor: _cyan.withOpacity(0.2),
                                  child: Text(
                                    _authorInitial(answer.authorName),
                                    style: const TextStyle(
                                      color: Color(0xFF27D9D3),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    answer.authorName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (answer.isAiGenerated)
                                  Container(
                                    margin: const EdgeInsets.only(right: 6),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6366F1).withOpacity(0.22),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFF818CF8).withOpacity(0.4)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('🤖 ', style: TextStyle(fontSize: 10)),
                                        Text(
                                          'AI Assistant',
                                          style: TextStyle(
                                            color: Color(0xFF818CF8),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (answer.isAccepted)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _green.withOpacity(0.18),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(Icons.check_circle, size: 11, color: Color(0xFF10B981)),
                                        SizedBox(width: 3),
                                        Text(
                                          'Accepted',
                                          style: TextStyle(
                                            color: Color(0xFF10B981),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (answer.createdAt != null) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    _formatTimeAgo(answer.createdAt),
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              answer.content,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      )),
                    if (isEscalated)
                      Container(
                        margin: const EdgeInsets.only(top: 6, bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFF59E0B)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '⚠️ Escalated to Faculty Mentor. Your assigned instructor will review this doubt.',
                                style: TextStyle(color: Color(0xFFF59E0B), fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (answers.isNotEmpty || qa.isAnswered)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 10),
                        child: OutlinedButton.icon(
                          onPressed: isEscalating
                              ? null
                              : () async {
                                  setSheetState(() => isEscalating = true);
                                  try {
                                    final res = await ApiService().post('/api/questions/${qa.id}/escalate', {});
                                    if (res != null) {
                                      setSheetState(() {
                                        isEscalated = true;
                                        isEscalating = false;
                                      });
                                      _loadQuestions();
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('⚠️ Doubt escalated to batch faculty mentor!'),
                                            backgroundColor: Color(0xFFF59E0B),
                                          ),
                                        );
                                      }
                                    } else {
                                      setSheetState(() => isEscalating = false);
                                    }
                                  } catch (_) {
                                    setSheetState(() => isEscalating = false);
                                  }
                                },
                          icon: isEscalating
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF59E0B)))
                              : const Icon(Icons.warning_amber_rounded, size: 15, color: Color(0xFFF59E0B)),
                          label: Text(
                            isEscalating ? 'Escalating...' : 'Not satisfied? Escalate to Faculty Mentor',
                            style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFF59E0B)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    // Answer input
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF104476).withOpacity(0.55),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.15)),
                      ),
                      child: TextField(
                        controller: answerCtrl,
                        cursorColor: _cyan,
                        maxLines: 2,
                        style: const TextStyle(color: Colors.white, fontSize: 13.5),
                        decoration: const InputDecoration(
                          filled: true,
                          fillColor: Colors.transparent,
                          hintText: 'Write your answer or response...',
                          hintStyle: TextStyle(color: Colors.white54, fontSize: 13),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.all(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: submittingAnswer
                            ? null
                            : () async {
                                if (answerCtrl.text.trim().isEmpty) return;
                                setSheetState(() => submittingAnswer = true);
                                final result = await ApiService()
                                    .postQuestionAnswer(qa.id, answerCtrl.text.trim());
                                if (result != null) {
                                  answerCtrl.clear();
                                  // Refresh answers in the sheet
                                  final refreshed =
                                      await ApiService().getAnswersByQuestion(qa.id);
                                  setSheetState(() {
                                    answers = refreshed;
                                    submittingAnswer = false;
                                  });
                                  // Refresh the main question list so counts update
                                  _loadQuestions();
                                } else {
                                  setSheetState(() => submittingAnswer = false);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Failed to submit answer'),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                  }
                                }
                              },
                        icon: submittingAnswer
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF041838),
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 15),
                        label: Text(submittingAnswer ? 'Submitting...' : 'Submit Answer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _cyan,
                          foregroundColor: const Color(0xFF041838),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNavBarHidden = ref.watch(shellNavBarHiddenProvider);
    return CommonHeaderScaffold(
      subtitle: 'Q&A',
      backgroundColor: _bgDark,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _cyan))
          : Column(
              children: [
                // Top Community Banner
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F3268), Color(0xFF164789)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFF1E5BB0).withOpacity(0.50)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _cyan.withOpacity(0.20),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.forum_rounded,
                            color: _cyan, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Community Q&A',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${_questions.length} questions • ${_questions.where((q) => q.isAnswered).length} answered',
                              style: const TextStyle(
                                color: Color(0xFF93C5FD),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () =>
                            setState(() => _showAskForm = !_showAskForm),
                        icon: Icon(
                          _showAskForm
                              ? Icons.close_rounded
                              : Icons.add_rounded,
                          size: 16,
                        ),
                        label: Text(_showAskForm ? 'Close' : 'Ask'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _cyan,
                          foregroundColor: const Color(0xFF041838),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Collapsible Ask Form
                if (_showAskForm)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _cardDark.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFF1E5BB0).withOpacity(0.60)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ask a Question',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF104476).withOpacity(0.55),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.15)),
                          ),
                          child: TextField(
                            controller: _titleController,
                            cursorColor: _cyan,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13.5),
                            decoration: const InputDecoration(
                              filled: true,
                              fillColor: Colors.transparent,
                              hintText: 'Question title...',
                              hintStyle: TextStyle(
                                  color: Colors.white54, fontSize: 13),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF104476).withOpacity(0.55),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.15)),
                          ),
                          child: TextField(
                            controller: _questionController,
                            cursorColor: _cyan,
                            maxLines: 3,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13.5),
                            decoration: const InputDecoration(
                              filled: true,
                              fillColor: Colors.transparent,
                              hintText: 'Describe your question in detail...',
                              hintStyle: TextStyle(
                                  color: Colors.white54, fontSize: 13),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: ['Java', 'SQL', 'DSA', 'Web', 'Coding']
                                    .map(
                                      (tag) => InkWell(
                                        onTap: () => setState(
                                            () => _categoryController.text = tag),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color:
                                                _categoryController.text == tag
                                                    ? _cyan.withOpacity(0.25)
                                                    : Colors.white.withOpacity(0.08),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color: _categoryController
                                                          .text ==
                                                      tag
                                                  ? _cyan
                                                  : Colors.white12,
                                            ),
                                          ),
                                          child: Text(
                                            tag,
                                            style: TextStyle(
                                              color: _categoryController
                                                          .text ==
                                                      tag
                                                  ? _cyan
                                                  : Colors.white70,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed:
                                  _isSubmitting ? null : _submitQuestion,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _cyan,
                                foregroundColor: const Color(0xFF041838),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF041838)),
                                    )
                                  : const Text('Post',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                // Category Filter Pills
                SizedBox(
                  height: 42,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filters.length,
                    itemBuilder: (context, index) {
                      final filter = _filters[index];
                      final isSelected = _selectedFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () =>
                              setState(() => _selectedFilter = filter),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF104476)
                                  : Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? _cyan
                                    : Colors.white.withOpacity(0.12),
                              ),
                            ),
                            child: Text(
                              filter,
                              style: TextStyle(
                                color: isSelected ? _cyan : Colors.white70,
                                fontSize: 12.5,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),

                // Questions List
                Expanded(
                  child: _filteredQuestions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.forum_outlined,
                                  size: 60, color: Colors.white24),
                              const SizedBox(height: 12),
                              const Text('No questions found',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 16)),
                              const SizedBox(height: 4),
                              const Text('Be the first to ask a question!',
                                  style: TextStyle(
                                      color: Colors.white38, fontSize: 12)),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadQuestions,
                          color: _cyan,
                          backgroundColor: const Color(0xFF092350),
                          child: ListView.builder(
                            padding: EdgeInsets.fromLTRB(16, 8, 16, isNavBarHidden ? 24 : 90),
                            itemCount: _filteredQuestions.length,
                            itemBuilder: (context, index) {
                              final qa = _filteredQuestions[index];
                              return _QuestionCard(
                                qa: qa,
                                formatTimeAgo: _formatTimeAgo,
                                categoryColor: _categoryColor,
                                authorInitial: _authorInitial,
                                onTap: () => _showQuestionDetails(qa),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final QuestionModel qa;
  final String Function(String?) formatTimeAgo;
  final Color Function(String) categoryColor;
  final String Function(String) authorInitial;
  final VoidCallback onTap;

  const _QuestionCard({
    required this.qa,
    required this.formatTimeAgo,
    required this.categoryColor,
    required this.authorInitial,
    required this.onTap,
  });

  static const _cardDark = Color(0xFF0C2B64);
  static const _cyan = Color(0xFF27D9D3);
  static const _green = Color(0xFF10B981);
  static const _amber = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    final authorColor = categoryColor(qa.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardDark.withOpacity(0.70),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1E5BB0).withOpacity(0.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.20),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: authorColor.withOpacity(0.20),
                      child: Text(
                        authorInitial(qa.authorName),
                        style: TextStyle(
                          color: authorColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            qa.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${qa.authorName} • ${formatTimeAgo(qa.createdAt)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: authorColor.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        qa.category,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: authorColor,
                        ),
                      ),
                    ),
                  ],
                ),
                if (qa.content.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    qa.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Colors.white70,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: qa.isAnswered
                            ? _green.withOpacity(0.20)
                            : _amber.withOpacity(0.20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            qa.isAnswered
                                ? Icons.check_circle_rounded
                                : Icons.hourglass_empty_rounded,
                            size: 13,
                            color: qa.isAnswered ? _green : _amber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${qa.answerCount} Answers',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: qa.isAnswered ? _green : _amber,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (qa.isEscalated)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: _amber.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _amber.withOpacity(0.4)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 11, color: Color(0xFFF59E0B)),
                            SizedBox(width: 3),
                            Text('Escalated', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B))),
                          ],
                        ),
                      ),
                    if (qa.isAiAnswered && !qa.isEscalated)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF818CF8).withOpacity(0.4)),
                        ),
                        child: const Row(
                          children: [
                            Text('🤖 ', style: TextStyle(fontSize: 9)),
                            Text('AI Answered', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF818CF8))),
                          ],
                        ),
                      ),
                    const SizedBox(width: 12),
                    const Icon(Icons.thumb_up_alt_outlined,
                        size: 14, color: Colors.white60),
                    const SizedBox(width: 4),
                    Text(
                      '${qa.voteCount}',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                    const Spacer(),
                    const Text(
                      'View & Answer →',
                      style: TextStyle(
                        fontSize: 12,
                        color: _cyan,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
