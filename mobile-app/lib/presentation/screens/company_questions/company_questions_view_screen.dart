import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/api_service.dart';
import '../../../core/widgets/common_header.dart';

const Color _kInk = Color(0xFF0F172A);
const Color _kAccent = Color(0xFFEAB308);
const Color _kMuted = Color(0xFF64748B);
const Color _kCorrect = Color(0xFF10B981);

/// A read-only "Q&A blog" view for a company tile.
///
/// Company questions are an interview-prep quick guide, not an assessment: the
/// student reads each question together with its answer, so there is no input,
/// no submit, no evaluation and no grading here. Coding questions render their
/// reference solution in a proper, copyable code block.
class CompanyQuestionsViewScreen extends StatefulWidget {
  final int assessmentId;
  final String companyName;
  final String? companyDescription;

  const CompanyQuestionsViewScreen({
    super.key,
    required this.assessmentId,
    required this.companyName,
    this.companyDescription,
  });

  @override
  State<CompanyQuestionsViewScreen> createState() =>
      _CompanyQuestionsViewScreenState();
}

class _CompanyQuestionsViewScreenState extends State<CompanyQuestionsViewScreen> {
  final ApiService _api = ApiService();

  bool _loading = true;
  String? _error;
  List<_GuideQuestion> _questions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final guide = await _api.getCompanyKitGuide(widget.assessmentId);
      if (guide == null) {
        setState(() {
          _loading = false;
          _error = 'These questions could not be loaded. Please try again.';
        });
        return;
      }
      final raw = guide['questions'];
      final questions = raw is List
          ? raw
              .whereType<Map>()
              .map((m) => _GuideQuestion.fromJson(Map<String, dynamic>.from(m)))
              .toList()
          : <_GuideQuestion>[];
      setState(() {
        _questions = questions;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: CommonHeader(
        title: widget.companyName,
        showBackButton: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _questions.isEmpty
                  ? _buildEmpty()
                  : _buildBlog(),
    );
  }
  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.menu_book_outlined, size: 56, color: _kMuted),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: _kMuted)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(backgroundColor: _kInk, foregroundColor: Colors.white),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.menu_book_outlined, size: 56, color: _kMuted),
            const SizedBox(height: 16),
            Text(
              'No questions have been added for this company yet.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _kMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlog() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _buildIntro(),
        const SizedBox(height: 16),
        Text(
          '${_questions.length} interview questions with answers',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kMuted),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < _questions.length; i++) _buildQuestionCard(_questions[i], i),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'A quick-guide only — nothing here is graded or saved.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ),
      ],
    );
  }

  Widget _buildIntro() {
    final desc = widget.companyDescription;
    if (desc == null || desc.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.tips_and_updates_outlined, color: _kAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              desc,
              style: const TextStyle(fontSize: 14, height: 1.45, color: _kInk),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(_GuideQuestion q, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _pill('Q${index + 1}', _kInk),
              const SizedBox(width: 8),
              _pill(q.typeLabel, q.typeColor),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            q.text,
            style: const TextStyle(
              fontSize: 15,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: _kInk,
            ),
          ),
          const SizedBox(height: 14),
          ..._buildAnswer(q),
          if (q.isChoice && q.options.isEmpty) ...[
            _answerBox(_kMuted, 'Answer', 'No options have been added for this question.'),
          ],
          if ((q.explanation ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _explanationBox(q.explanation!),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildAnswer(_GuideQuestion q) {
    if (q.isCoding) {
      return [
        _answerBox(
          _kInk,
          'Solution',
          (q.answerText ?? '').trim().isEmpty
              ? 'No sample solution provided for this coding question.'
              : q.answerText!,
          code: true,
        ),
      ];
    }
    if (q.isChoice) {
      return q.options
          .map((o) => _optionRow(q, o))
          .toList();
    }
    // FILL_IN_BLANK
    return [
      _answerBox(
        _kCorrect,
        'Answer',
        (q.answerText ?? '').trim().isEmpty ? 'No answer provided.' : q.answerText!,
      ),
    ];
  }
Widget _optionRow(_GuideQuestion q, _GuideOption option) {
    final isCorrect = option.isCorrect;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCorrect ? _kCorrect.withOpacity(0.08) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: isCorrect ? _kCorrect.withOpacity(0.5) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${String.fromCharCode(65 + option.index)}.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isCorrect ? _kCorrect : _kMuted,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              option.text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isCorrect ? FontWeight.w700 : FontWeight.w400,
                color: isCorrect ? const Color(0xFF065F46) : _kInk,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (isCorrect)
            const Icon(Icons.check_circle, size: 20, color: _kCorrect)
          else
            Icon(Icons.circle_outlined, size: 20, color: Colors.grey.shade300),
        ],
      ),
    );
  }

  Widget _answerBox(Color accent, String label, String content, {bool code = false}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(11),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: accent,
                letterSpacing: 0.6,
              ),
            ),
          ),
          if (code)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: _codeBlock(code: content),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Text(
                content,
                style: const TextStyle(fontSize: 14, height: 1.45, color: _kInk),
              ),
            ),
        ],
      ),
    );
  }

  /// Dark, monospaced, horizontally-scrollable code block with a copy action.
  Widget _codeBlock({required String code}) {
    // Trim away one shared leading indentation so pasted code reads naturally.
    final lines = code.replaceAll('\r\n', '\n').split('\n');
    var minIndent = 1 << 30;
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final indent = line.length - line.trimLeft().length;
      if (indent < minIndent) minIndent = indent;
    }
    final normalized = minIndent == 1 << 30
        ? code
        : lines.map((l) => l.length >= minIndent ? l.substring(minIndent) : l).join('\n');

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFF1E293B),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.code, size: 14, color: Color(0xFF94A3B8)),
                const SizedBox(width: 6),
                const Text(
                  'CODE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: normalized));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Solution copied'), duration: Duration(seconds: 1)),
                    );
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.copy_rounded, size: 15, color: Color(0xFFCBD5E1)),
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              normalized,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.45,
                color: Color(0xFFE2E8F0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _explanationBox(String explanation) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF9C3),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Why / Explanation',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF92400E),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            explanation,
            style: const TextStyle(fontSize: 13, height: 1.45, color: Color(0xFF78350F)),
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

/// One guide question fetched from the server with its full answer key.
class _GuideQuestion {
  final int id;
  final String text;
  final String questionType;
  final String? explanation;
  final String? answerText;
  final List<_GuideOption> options;

  const _GuideQuestion({
    required this.id,
    required this.text,
    required this.questionType,
    this.explanation,
    this.answerText,
    this.options = const [],
  });

  bool get isChoice => questionType == 'SINGLE_CHOICE' || questionType == 'MULTIPLE_ANSWER';
  bool get isCoding => questionType == 'CODING';

  String get typeLabel {
    switch (questionType) {
      case 'MULTIPLE_ANSWER':
        return 'Multiple answers';
      case 'CODING':
        return 'Coding';
      case 'FILL_IN_BLANK':
        return 'Fill in the blank';
      default:
        return 'Multiple choice';
    }
  }

  Color get typeColor {
    switch (questionType) {
      case 'CODING':
        return const Color(0xFF4338CA);
      case 'FILL_IN_BLANK':
        return const Color(0xFF047857);
      case 'MULTIPLE_ANSWER':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF2563EB);
    }
  }

  factory _GuideQuestion.fromJson(Map<String, dynamic> json) {
    final rawOptions = (json['options'] as List?) ?? const [];
    return _GuideQuestion(
      id: (json['id'] as num?)?.toInt() ?? 0,
      text: json['questionText'] ?? '',
      questionType: json['questionType'] ?? 'SINGLE_CHOICE',
      explanation: json['explanation'],
      answerText: json['answerText'],
      options: rawOptions
          .whereType<Map>()
          .map((m) => _GuideOption.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
    );
  }
}

class _GuideOption {
  final String text;
  final bool isCorrect;
  final int index;

  const _GuideOption({required this.text, required this.isCorrect, required this.index});

  factory _GuideOption.fromJson(Map<String, dynamic> json) => _GuideOption(
        text: json['optionText'] ?? '',
        isCorrect: json['isCorrect'] == true,
        index: (json['displayOrder'] as num?)?.toInt() ?? 0,
      );
}