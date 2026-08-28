import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/api_service.dart';

const Color _kInk = Color(0xFF0F172A);
const Color _kAccent = Color(0xFFEAB308);
const Color _kCorrect = Color(0xFF10B981);
const Color _kWrong = Color(0xFFEF4444);
const Color _kMuted = Color(0xFF64748B);
const Color _kPaper = Color(0xFFF8FAFC);

/// The in-app question paper for an assignment or exam.
///
/// Papers whose delivery mode is WEB never reach this screen - those keep opening
/// their link in the embedded browser. Here the student answers the questions the
/// admin authored, submits once, and is auto-graded on the way back: the same
/// response carries the answer key and explanations for the review view, so the
/// key never travels to the device before the attempt is committed.
class AssessmentPaperScreen extends StatefulWidget {
  /// 'assignments' or 'exams', matching the API path.
  final String type;
  final int assessmentId;
  final String title;

  /// Only exams carry a duration; when present the paper is timed and auto-submits.
  final int? durationMinutes;
  final int? totalMarks;

  const AssessmentPaperScreen({
    super.key,
    required this.type,
    required this.assessmentId,
    required this.title,
    this.durationMinutes,
    this.totalMarks,
  });

  @override
  State<AssessmentPaperScreen> createState() => _AssessmentPaperScreenState();
}

class _AssessmentPaperScreenState extends State<AssessmentPaperScreen> {
  final ApiService _api = ApiService();
  final PageController _pages = PageController();

  bool _loading = true;
  bool _submitting = false;
  String? _error;
  int? _userId;

  List<_Question> _questions = [];
  int _paperMarks = 0;
  int _current = 0;

  /// questionId -> the option ids ticked so far.
  final Map<int, List<int>> _answers = {};

  /// Questions the student explicitly flagged to come back to.
  final Set<int> _flagged = {};

  Timer? _ticker;
  int _elapsedSeconds = 0;
  int? _remainingSeconds;

  /// The clock ran out. Kept separate from [_result] because the auto-submit can
  /// fail, and the student must still be able to retry from any page.
  bool _timeUp = false;

  /// Non-null once the attempt has been graded - the screen then renders the review.
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pages.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ loading

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');
      if (userId == null) {
        setState(() {
          _loading = false;
          _error = 'Please log in again to open this paper.';
        });
        return;
      }
      _userId = userId;

      final paper = await _api.getAssessmentPaper(widget.type, widget.assessmentId, userId);
      if (paper == null) {
        setState(() {
          _loading = false;
          _error = 'This paper could not be loaded. Please try again.';
        });
        return;
      }

      // Already attempted: skip straight to the review instead of letting the
      // student answer a paper whose result is already on record.
      if (paper['alreadySubmitted'] == true) {
        final review = await _api.getAssessmentReview(widget.type, widget.assessmentId, userId);
        if (review != null && review['attempted'] == true) {
          setState(() {
            _result = review;
            _questions = _parseQuestions(review['questions']);
            _paperMarks = (review['totalMarks'] as num?)?.toInt() ?? 0;
            _loading = false;
          });
          return;
        }
      }

      final questions = _parseQuestions(paper['questions']);
      if (questions.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'No questions have been added to this paper yet.';
        });
        return;
      }

      setState(() {
        _questions = questions;
        _paperMarks = (paper['totalMarks'] as num?)?.toInt() ?? widget.totalMarks ?? 0;
        _loading = false;
      });
      _startTimer();
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  List<_Question> _parseQuestions(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((m) => _Question.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// Safe to call again after a failed submit: the remaining time is only seeded
  /// on the first run, so retrying does not hand back a fresh clock.
  void _startTimer() {
    final minutes = widget.durationMinutes;
    if (_remainingSeconds == null && minutes != null && minutes > 0) {
      _remainingSeconds = minutes * 60;
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsedSeconds++;
        final remaining = _remainingSeconds;
        if (remaining != null) _remainingSeconds = remaining - 1;
      });
      // Time up: submit whatever is answered so the attempt is never lost.
      if (_remainingSeconds != null && _remainingSeconds! <= 0) {
        _ticker?.cancel();
        setState(() => _timeUp = true);
        _submit(auto: true);
      }
    });
  }

  // ------------------------------------------------------------------ answering

  void _toggleOption(_Question q, int optionId) {
    setState(() {
      final selected = _answers[q.id] ?? <int>[];
      if (q.isMultiple) {
        if (selected.contains(optionId)) {
          selected.remove(optionId);
        } else {
          selected.add(optionId);
        }
        if (selected.isEmpty) {
          _answers.remove(q.id);
        } else {
          _answers[q.id] = selected;
        }
      } else {
        // Single choice behaves like a radio group - tapping the current pick clears it.
        if (selected.length == 1 && selected.first == optionId) {
          _answers.remove(q.id);
        } else {
          _answers[q.id] = [optionId];
        }
      }
    });
    HapticFeedback.selectionClick();
  }

  int get _answeredCount => _questions.where((q) => (_answers[q.id] ?? const []).isNotEmpty).length;

  void _goTo(int index) {
    if (index < 0 || index >= _questions.length) return;
    _pages.animateToPage(index,
        duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  // ------------------------------------------------------------------ submitting

  Future<void> _confirmSubmit() async {
    final unanswered = _questions.length - _answeredCount;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Submit paper?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _summaryRow('Answered', '$_answeredCount of ${_questions.length}'),
            if (unanswered > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '$unanswered question${unanswered == 1 ? '' : 's'} left blank will be marked wrong.',
                  style: const TextStyle(fontSize: 13, color: _kWrong),
                ),
              ),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('You cannot change your answers after submitting.',
                  style: TextStyle(fontSize: 13, color: _kMuted)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep working')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _kInk, foregroundColor: Colors.white),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (ok == true) _submit();
  }

  Widget _summaryRow(String label, String value) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: _kMuted)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      );

  Future<void> _submit({bool auto = false}) async {
    if (_submitting || _result != null) return;
    setState(() => _submitting = true);
    _ticker?.cancel();

    final result = await _api.submitAssessmentAttempt(
      widget.type,
      widget.assessmentId,
      _userId!,
      _answers,
      timeTakenSeconds: _elapsedSeconds,
    );

    if (!mounted) return;
    if (result == null) {
      setState(() => _submitting = false);
      // Resume the clock only if it had not already expired, otherwise the retry
      // would fire again on the next tick.
      if (!_timeUp) _startTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not submit. Check your connection and try again.'),
            backgroundColor: _kWrong),
      );
      return;
    }

    setState(() {
      _submitting = false;
      _result = result;
      _questions = _parseQuestions(result['questions']);
      _paperMarks = (result['totalMarks'] as num?)?.toInt() ?? _paperMarks;
    });
    if (auto) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Time is up - your paper was submitted automatically.'),
            backgroundColor: _kAccent),
      );
    }
  }

  /// Leaving mid-paper throws the attempt away, so make that explicit.
  Future<bool> _confirmExit() async {
    if (_result != null || _questions.isEmpty || _answeredCount == 0) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Leave the paper?'),
        content: const Text('Your answers have not been submitted and will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave', style: TextStyle(color: _kWrong)),
          ),
        ],
      ),
    );
    return leave == true;
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _confirmExit() && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: _kPaper,
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _buildError()
                  : _result != null
                      ? _buildReview()
                      : _buildPaper(),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Column(
      children: [
        _topBar(),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.description_outlined, size: 56, color: _kMuted),
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
          ),
        ),
      ],
    );
  }

  Widget _topBar({Widget? trailing}) {
    return Container(
      color: _kInk,
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () async {
              if (await _confirmExit() && mounted) Navigator.of(context).pop();
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                ),
                Text(
                  '${_questions.length} question${_questions.length == 1 ? '' : 's'}'
                  '${_paperMarks > 0 ? '  -  $_paperMarks marks' : ''}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ answering view

  Widget _buildPaper() {
    return Column(
      children: [
        _topBar(trailing: _remainingSeconds != null ? _timerChip() : null),
        _progressStrip(),
        Expanded(
          child: PageView.builder(
            controller: _pages,
            onPageChanged: (i) => setState(() => _current = i),
            itemCount: _questions.length,
            itemBuilder: (_, i) => _questionPage(_questions[i], i),
          ),
        ),
        _bottomBar(),
      ],
    );
  }

  Widget _timerChip() {
    final seconds = _remainingSeconds ?? 0;
    final low = seconds <= 60;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: low ? _kWrong : Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(_formatClock(seconds < 0 ? 0 : seconds),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  static String _formatClock(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  Widget _progressStrip() {
    final progress = _questions.isEmpty ? 0.0 : _answeredCount / _questions.length;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        children: [
          Row(
            children: [
              Text('Question ${_current + 1} of ${_questions.length}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kInk)),
              const Spacer(),
              Text('$_answeredCount answered', style: const TextStyle(fontSize: 12, color: _kMuted)),
              const SizedBox(width: 10),
              InkWell(
                onTap: _showPalette,
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.grid_view_rounded, size: 18, color: _kInk),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation(_kCorrect),
            ),
          ),
        ],
      ),
    );
  }

  /// Jump-to-question grid, the way a real exam interface works.
  void _showPalette() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Jump to question',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _kInk)),
            const SizedBox(height: 4),
            const Text('Green = answered, amber = flagged for review',
                style: TextStyle(fontSize: 12, color: _kMuted)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(_questions.length, (i) {
                final q = _questions[i];
                final answered = (_answers[q.id] ?? const []).isNotEmpty;
                final flagged = _flagged.contains(q.id);
                final color = flagged ? _kAccent : (answered ? _kCorrect : const Color(0xFFE2E8F0));
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    _goTo(i);
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: i == _current ? _kInk : Colors.transparent, width: 2),
                    ),
                    child: Text('${i + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: (answered || flagged) ? Colors.white : _kInk,
                        )),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _questionPage(_Question q, int index) {
    final selected = _answers[q.id] ?? const <int>[];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
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
                    _pill(q.isMultiple ? 'Multiple answers' : 'Single choice',
                        q.isMultiple ? const Color(0xFF7C3AED) : const Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    _pill('${q.marks} mark${q.marks == 1 ? '' : 's'}', _kMuted),
                    const Spacer(),
                    InkWell(
                      onTap: () => setState(() =>
                          _flagged.contains(q.id) ? _flagged.remove(q.id) : _flagged.add(q.id)),
                      child: Icon(
                        _flagged.contains(q.id) ? Icons.flag : Icons.outlined_flag,
                        size: 20,
                        color: _flagged.contains(q.id) ? _kAccent : _kMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(q.text,
                    style: const TextStyle(
                        fontSize: 16, height: 1.45, fontWeight: FontWeight.w600, color: _kInk)),
                if (q.isMultiple)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Select all that apply.',
                        style: TextStyle(fontSize: 12, color: _kMuted, fontStyle: FontStyle.italic)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(q.options.length, (i) {
            final option = q.options[i];
            final isSelected = selected.contains(option.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _toggleOption(q, option.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                        width: isSelected ? 2 : 1),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _optionMarker(_letter(i), isSelected, q.isMultiple),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(option.text,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.4,
                              color: _kInk,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            )),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// A square marker reads as a checkbox and a round one as a radio, which is the
  /// cue students use to tell "pick one" from "pick several" without reading.
  Widget _optionMarker(String letter, bool selected, bool multiple) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF2563EB) : Colors.transparent,
        shape: multiple ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: multiple ? BorderRadius.circular(7) : null,
        border: Border.all(
            color: selected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1), width: 2),
      ),
      child: selected
          ? const Icon(Icons.check, size: 17, color: Colors.white)
          : Text(letter,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kMuted)),
    );
  }

  static String _letter(int i) => String.fromCharCode(65 + i);

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _bottomBar() {
    // Once the clock has run out the only sensible action is to get the paper in,
    // from whichever question the student happens to be on.
    final isLast = _timeUp || _current == _questions.length - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          if (_current > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _goTo(_current - 1),
                icon: const Icon(Icons.chevron_left, size: 20),
                label: const Text('Previous'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: _kInk, padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
          if (_current > 0) const SizedBox(width: 10),
          Expanded(
            flex: isLast ? 2 : 1,
            child: isLast
                ? ElevatedButton.icon(
                    onPressed: _submitting ? null : _confirmSubmit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Icon(Icons.check_circle_outline, size: 20),
                    label: Text(_submitting ? 'Submitting...' : 'Submit paper'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _kAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                  )
                : ElevatedButton.icon(
                    onPressed: () => _goTo(_current + 1),
                    icon: const Icon(Icons.chevron_right, size: 20),
                    label: const Text('Next'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _kInk,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ review view

  Widget _buildReview() {
    final result = _result!;
    final score = (result['score'] as num?)?.toInt() ?? 0;
    final total = (result['totalMarks'] as num?)?.toInt() ?? _paperMarks;
    final correct = (result['correctCount'] as num?)?.toInt() ?? 0;
    final count = (result['questionCount'] as num?)?.toInt() ?? _questions.length;
    final percentage = (result['percentage'] as num?)?.toDouble() ?? 0;

    return Column(
      children: [
        _topBar(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _scoreCard(score, total, correct, count, percentage),
              const SizedBox(height: 18),
              const Text('Answer review',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _kInk)),
              const SizedBox(height: 10),
              ...List.generate(_questions.length, (i) => _reviewCard(_questions[i], i)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _kInk,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Done'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _scoreCard(int score, int total, int correct, int count, double percentage) {
    final passed = percentage >= 40;
    final tone = passed ? _kCorrect : _kWrong;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tone.withOpacity(0.14), tone.withOpacity(0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tone.withOpacity(0.35)),
      ),
      child: Column(
        children: [
          Icon(passed ? Icons.emoji_events_outlined : Icons.replay_circle_filled_outlined,
              size: 44, color: tone),
          const SizedBox(height: 10),
          Text('$score / $total',
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: tone)),
          Text('${percentage.toStringAsFixed(1)}%  -  $correct of $count correct',
              style: const TextStyle(fontSize: 13, color: _kMuted)),
          const SizedBox(height: 14),
          Container(height: 1, color: tone.withOpacity(0.2)),
          const SizedBox(height: 14),
          const Text(
            'Your result has been recorded and shared with your mentor.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: _kMuted),
          ),
        ],
      ),
    );
  }

  Widget _reviewCard(_Question q, int index) {
    final selected = q.selectedOptionIds;
    final unanswered = selected.isEmpty;
    final tone = q.isCorrect ? _kCorrect : (unanswered ? _kMuted : _kWrong);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              _pill(
                q.isCorrect ? 'Correct' : (unanswered ? 'Not answered' : 'Incorrect'),
                tone,
              ),
              const Spacer(),
              Text('${q.marksAwarded}/${q.marks}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tone)),
            ],
          ),
          const SizedBox(height: 12),
          Text(q.text,
              style: const TextStyle(
                  fontSize: 15, height: 1.4, fontWeight: FontWeight.w600, color: _kInk)),
          const SizedBox(height: 12),
          ...List.generate(q.options.length, (i) {
            final option = q.options[i];
            final picked = selected.contains(option.id);
            final isKey = option.isCorrect;

            Color background = Colors.transparent;
            Color border = const Color(0xFFE2E8F0);
            if (isKey) {
              background = _kCorrect.withOpacity(0.10);
              border = _kCorrect;
            } else if (picked) {
              background = _kWrong.withOpacity(0.08);
              border = _kWrong;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_letter(i)}.',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: _kMuted)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(option.text, style: const TextStyle(fontSize: 14, height: 1.35))),
                    if (picked) ...[
                      const SizedBox(width: 8),
                      _tag('Your answer', isKey ? _kCorrect : _kWrong),
                    ],
                    if (isKey && !picked) ...[
                      const SizedBox(width: 8),
                      _tag('Correct', _kCorrect),
                    ],
                  ],
                ),
              ),
            );
          }),
          if ((q.explanation ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(11),
                border: const Border(left: BorderSide(color: _kInk, width: 3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Why',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _kInk, letterSpacing: 0.6)),
                  const SizedBox(height: 4),
                  Text(q.explanation!,
                      style: const TextStyle(fontSize: 13, height: 1.45, color: Color(0xFF334155))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
      child: Text(label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
    );
  }
}

// ---------------------------------------------------------------------------

/// One question. The answer-key fields ([_Option.isCorrect], [explanation],
/// [isCorrect], [marksAwarded]) are absent from the pre-submission payload and
/// only populated once the attempt comes back graded.
class _Question {
  final int id;
  final String text;
  final String questionType;
  final int marks;
  final String? explanation;
  final List<_Option> options;
  final List<int> selectedOptionIds;
  final bool isCorrect;
  final int marksAwarded;

  const _Question({
    required this.id,
    required this.text,
    required this.questionType,
    required this.marks,
    required this.options,
    this.explanation,
    this.selectedOptionIds = const [],
    this.isCorrect = false,
    this.marksAwarded = 0,
  });

  bool get isMultiple => questionType == 'MULTIPLE_ANSWER';

  factory _Question.fromJson(Map<String, dynamic> json) {
    final rawOptions = (json['options'] as List?) ?? const [];
    return _Question(
      id: (json['id'] as num?)?.toInt() ?? 0,
      text: json['questionText'] ?? '',
      questionType: json['questionType'] ?? 'SINGLE_CHOICE',
      marks: (json['marks'] as num?)?.toInt() ?? 1,
      explanation: json['explanation'],
      options: rawOptions
          .whereType<Map>()
          .map((o) => _Option.fromJson(Map<String, dynamic>.from(o)))
          .toList(),
      selectedOptionIds: ((json['selectedOptionIds'] as List?) ?? const [])
          .whereType<num>()
          .map((n) => n.toInt())
          .toList(),
      isCorrect: json['isCorrect'] == true,
      marksAwarded: (json['marksAwarded'] as num?)?.toInt() ?? 0,
    );
  }
}

class _Option {
  final int id;
  final String text;
  final bool isCorrect;

  const _Option({required this.id, required this.text, this.isCorrect = false});

  factory _Option.fromJson(Map<String, dynamic> json) => _Option(
        id: (json['id'] as num?)?.toInt() ?? 0,
        text: json['optionText'] ?? '',
        isCorrect: json['isCorrect'] == true,
      );
}
