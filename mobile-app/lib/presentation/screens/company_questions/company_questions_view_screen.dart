import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/data_providers.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/common_header.dart';

/// A read-only "Q&A blog" view for a company tile.
///
/// Company questions are an interview-prep quick guide, not an assessment: the
/// student reads each question together with its answer, so there is no input,
/// no submit, no evaluation and no grading here. Coding questions render their
/// reference solution in a proper, copyable code block.
class CompanyQuestionsViewScreen extends ConsumerStatefulWidget {
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
  ConsumerState<CompanyQuestionsViewScreen> createState() =>
      _CompanyQuestionsViewScreenState();
}

class _CompanyQuestionsViewScreenState
    extends ConsumerState<CompanyQuestionsViewScreen> {
  static const _bgDark = Color(0xFF071D43);
  static const _cardDark = Color(0xFF0C2B64);
  static const _cyan = Color(0xFF27D9D3);
  static const _amber = Color(0xFFF59E0B);
  static const _green = Color(0xFF10B981);

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
              .map((m) =>
                  _GuideQuestion.fromJson(Map<String, dynamic>.from(m)))
              .toList()
          : <_GuideQuestion>[];
      if (!mounted) return;
      setState(() {
        _questions = questions;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CommonHeaderScaffold(
      subtitle: widget.companyName,
      showBackButton: true,
      backgroundColor: _bgDark,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _cyan))
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
            const Icon(Icons.error_outline_rounded,
                size: 56, color: Colors.white38),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(
                backgroundColor: _cyan,
                foregroundColor: const Color(0xFF041838),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Try again',
                  style: TextStyle(fontWeight: FontWeight.bold)),
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
            const Icon(Icons.quiz_outlined, size: 56, color: Colors.white38),
            const SizedBox(height: 16),
            Text(
              'No questions have been added for ${widget.companyName} yet.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlog() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _buildIntro(),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_questions.length} Interview Questions with Answers',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF93C5FD),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _cyan.withOpacity(0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'PREP GUIDE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: _cyan,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < _questions.length; i++)
          _buildQuestionCard(_questions[i], i),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Quick-guide only — reading & learning mode.',
            style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4)),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _amber.withOpacity(0.20),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.tips_and_updates_rounded,
                color: _amber, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Company Overview',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(_GuideQuestion q, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardDark.withOpacity(0.70),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E5BB0).withOpacity(0.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.20),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _pill('Q${index + 1}', _cyan),
              const SizedBox(width: 8),
              _pill(q.typeLabel, q.typeColor),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            q.text,
            style: const TextStyle(
              fontSize: 15.5,
              height: 1.4,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          ..._buildAnswer(q),
          if (q.isChoice && q.options.isEmpty) ...[
            _answerBox(
              Colors.white60,
              'Answer',
              'No options have been added for this question.',
            ),
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
          _cyan,
          'Solution Code',
          (q.answerText ?? '').trim().isEmpty
              ? 'No sample solution provided for this coding question.'
              : q.answerText!,
          code: true,
        ),
      ];
    }
    if (q.isFillInBlank) {
      return [
        _answerBox(
          _green,
          'Correct Answer',
          (q.answerText ?? '').trim().isEmpty
              ? 'No answer provided.'
              : q.answerText!,
        ),
      ];
    }
    if (q.isMultipleAnswer) {
      final correctCount = q.options.where((o) => o.isCorrect).length;
      return [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              const Icon(Icons.check_box_outlined, size: 14, color: _green),
              const SizedBox(width: 6),
              Text(
                correctCount > 0
                    ? 'Select all that apply ($correctCount correct answers)'
                    : 'Multiple answers possible',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.70),
                ),
              ),
            ],
          ),
        ),
        ...q.options.map((o) => _optionRow(q, o, isMulti: true)),
        if (q.options.isEmpty && (q.answerText ?? '').isNotEmpty)
          _answerBox(
            _green,
            'Correct Answers',
            q.answerText!,
          ),
      ];
    }
    if (q.isChoice) {
      return [
        ...q.options.map((o) => _optionRow(q, o, isMulti: false)),
        if (q.options.isEmpty && (q.answerText ?? '').isNotEmpty)
          _answerBox(
            _green,
            'Correct Answer',
            q.answerText!,
          ),
      ];
    }
    // Default fallback
    return [
      _answerBox(
        _green,
        'Answer',
        (q.answerText ?? '').trim().isEmpty
            ? 'No answer provided.'
            : q.answerText!,
      ),
    ];
  }

  Widget _optionRow(_GuideQuestion q, _GuideOption option,
      {bool isMulti = false}) {
    final isCorrect = option.isCorrect;
    final optionLabel = String.fromCharCode(65 + option.index);
    final textDisplay = option.text.isNotEmpty
        ? option.text
        : 'Option $optionLabel';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCorrect
            ? _green.withOpacity(0.18)
            : Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCorrect ? _green : Colors.white12,
          width: isCorrect ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$optionLabel.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isCorrect ? _green : Colors.white60,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  textDisplay,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                    color: isCorrect ? Colors.white : Colors.white70,
                  ),
                ),
                if (isCorrect) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _green.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'CORRECT ANSWER',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: _green,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isCorrect)
            Icon(
              isMulti ? Icons.check_box_rounded : Icons.check_circle_rounded,
              size: 20,
              color: _green,
            )
          else
            Icon(
              isMulti
                  ? Icons.check_box_outline_blank_rounded
                  : Icons.circle_outlined,
              size: 20,
              color: Colors.white24,
            ),
        ],
      ),
    );
  }

  Widget _answerBox(Color accent, String label, String content,
      {bool code = false}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF092350).withOpacity(0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: accent, width: 3.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: accent,
                letterSpacing: 0.8,
              ),
            ),
          ),
          if (code)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: _codeBlock(code: content),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
              child: Text(
                content,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Dark, monospaced, horizontally-scrollable code block with copy action.
  Widget _codeBlock({required String code}) {
    final lines = code.replaceAll('\r\n', '\n').split('\n');
    var minIndent = 999;
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final indent = line.length - line.trimLeft().length;
      if (indent < minIndent) minIndent = indent;
    }
    final normalized = (minIndent > 0 && minIndent < 999)
        ? lines
            .map((l) => l.length >= minIndent ? l.substring(minIndent) : l)
            .join('\n')
        : code;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF030D1E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E5BB0).withOpacity(0.40)),
      ),
      child: Stack(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(14, 14, 48, 14),
            child: SelectableText(
              normalized,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.5,
                height: 1.45,
                color: Color(0xFFE2E8F0),
              ),
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.copy_rounded,
                    size: 16, color: Colors.white60),
                tooltip: 'Copy solution',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: normalized));
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Solution copied to clipboard!'),
                      backgroundColor: Color(0xFF10B981),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _explanationBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D3365).withOpacity(0.50),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cyan.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 16, color: _cyan),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class _GuideOption {
  final int index;
  final String text;
  final bool isCorrect;
  const _GuideOption({
    required this.index,
    required this.text,
    required this.isCorrect,
  });

  factory _GuideOption.fromJson(Map<String, dynamic> json, int index) {
    return _GuideOption(
      index: index,
      text: (json['optionText'] as String? ?? json['text'] as String? ?? '').trim(),
      isCorrect: json['isCorrect'] == true,
    );
  }
}

class _GuideQuestion {
  final int id;
  final String text;
  final String type;
  final String? answerText;
  final String? explanation;
  final List<_GuideOption> options;

  const _GuideQuestion({
    required this.id,
    required this.text,
    required this.type,
    this.answerText,
    this.explanation,
    this.options = const [],
  });

  bool get isCoding => type == 'CODING';
  bool get isFillInBlank => type == 'FILL_IN_BLANK';
  bool get isMultipleAnswer =>
      type == 'MULTIPLE_ANSWER' ||
      type == 'MULTI_CHOICE' ||
      type == 'MULTIPLE_CHOICE_MULTI';
  bool get isSingleChoice =>
      type == 'SINGLE_CHOICE' ||
      type == 'MULTIPLE_CHOICE' ||
      type == 'TRUE_FALSE';
  bool get isChoice => isSingleChoice || isMultipleAnswer;

  String get typeLabel {
    switch (type) {
      case 'MULTIPLE_ANSWER':
      case 'MULTI_CHOICE':
      case 'MULTIPLE_CHOICE_MULTI':
        return 'Multiple Answers';
      case 'SINGLE_CHOICE':
      case 'MULTIPLE_CHOICE':
        return 'Multiple Choice';
      case 'TRUE_FALSE':
        return 'True / False';
      case 'CODING':
        return 'Coding';
      case 'FILL_IN_BLANK':
        return 'Fill in the Blank';
      default:
        return type;
    }
  }

  Color get typeColor {
    switch (type) {
      case 'CODING':
        return const Color(0xFF9B5CFF);
      case 'MULTIPLE_ANSWER':
      case 'MULTI_CHOICE':
      case 'MULTIPLE_CHOICE_MULTI':
        return const Color(0xFF10B981);
      case 'TRUE_FALSE':
        return const Color(0xFFEAB308);
      case 'FILL_IN_BLANK':
        return const Color(0xFFF97316);
      default:
        return const Color(0xFF27D9D3);
    }
  }

  factory _GuideQuestion.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    final options = <_GuideOption>[];
    if (rawOptions is List) {
      for (var i = 0; i < rawOptions.length; i++) {
        final opt = rawOptions[i];
        if (opt is Map) {
          options.add(
              _GuideOption.fromJson(Map<String, dynamic>.from(opt), i));
        }
      }
    }
    final rawType = (json['questionType'] as String? ??
            json['type'] as String? ??
            'SINGLE_CHOICE')
        .toUpperCase();
    return _GuideQuestion(
      id: (json['id'] as num?)?.toInt() ?? 0,
      text: json['questionText'] as String? ??
          json['text'] as String? ??
          '',
      type: rawType,
      answerText: json['answerText'] as String? ??
          json['correctAnswer'] as String? ??
          json['modelAnswer'] as String?,
      explanation: json['explanation'] as String?,
      options: options,
    );
  }
}
