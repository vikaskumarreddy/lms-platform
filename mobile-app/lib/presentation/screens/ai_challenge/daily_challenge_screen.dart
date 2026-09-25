import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/routes.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/common_header.dart';

class DailyChallengeScreen extends ConsumerStatefulWidget {
  const DailyChallengeScreen({super.key});

  @override
  ConsumerState<DailyChallengeScreen> createState() => _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends ConsumerState<DailyChallengeScreen> {
  static const _bgDark = Color(0xFF071D43);
  static const _cardDark = Color(0xFF0C2B64);
  static const _cyan = Color(0xFF27D9D3);
  static const _green = Color(0xFF10B981);
  static const _red = Color(0xFFEF4444);
  static const _indigo = Color(0xFF6366F1);

  bool _loading = true;
  bool _completedToday = false;
  Map<String, dynamic>? _todayAttempt;

  // Selection Phase
  List<dynamic> _courses = [];
  int? _selectedCourseId;
  List<dynamic> _modules = [];
  int? _selectedLessonId;
  String _selectedDifficulty = 'low';
  bool _loadingModules = false;

  // Challenge Phase
  bool _inChallenge = false;
  String? _challengeToken;
  List<dynamic> _questions = [];
  int _currentQuestionIndex = 0;
  final Map<String, int> _userAnswers = {}; // questionIndex -> chosenOptionIndex
  Timer? _timer;
  int _remainingSeconds = 300; // 5 minutes

  // Result Phase
  bool _submitting = false;
  Map<String, dynamic>? _submissionResult;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().get('/api/ai/daily-challenge/status');
      if (res is Map) {
        final map = Map<String, dynamic>.from(res);
        _completedToday = map['completedToday'] == true || map['hasCompletedToday'] == true;
        _todayAttempt = map;
        if (map['review'] != null) {
          _submissionResult = map;
        }
      }
      if (!_completedToday) {
        await _loadCourses();
      }
    } catch (e) {
      debugPrint('Error checking daily challenge status: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadCourses() async {
    try {
      final courses = await ApiService().getCourses();
      if (mounted) {
        setState(() {
          _courses = courses.map((c) => {'id': c.id, 'title': c.title}).toList();
        });
      }
    } catch (e) {
      debugPrint('Failed to load courses: $e');
    }
  }

  Future<void> _loadCourseModules(int courseId) async {
    setState(() {
      _loadingModules = true;
      _selectedCourseId = courseId;
      _selectedLessonId = null;
      _modules = [];
    });
    try {
      final res = await ApiService().get('/courses/$courseId');
      if (res != null && mounted) {
        final rawModules = (res is Map && res['modules'] is List) ? res['modules'] as List : [];
        setState(() {
          _modules = rawModules.map((m) {
            final lessons = (m is Map && m['lessons'] is List) ? m['lessons'] as List : [];
            return {
              'id': m['id'],
              'title': m['title']?.toString() ?? 'Module',
              'lessons': lessons.map((l) => {
                'id': l['id'],
                'title': l['title']?.toString() ?? 'Lesson',
              }).toList(),
            };
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Failed to load course modules: $e');
    } finally {
      if (mounted) setState(() => _loadingModules = false);
    }
  }

  Future<void> _startChallenge() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().post('/api/ai/daily-challenge/start', {
        'lessonId': _selectedLessonId,
        'difficulty': _selectedDifficulty,
      });

      if (res != null && res['questions'] != null) {
        setState(() {
          _challengeToken = res['challengeToken']?.toString() ?? '';
          _questions = res['questions'] as List<dynamic>;
          _currentQuestionIndex = 0;
          _userAnswers.clear();
          _inChallenge = true;
          _remainingSeconds = 300;
        });

        _timer?.cancel();
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) return;
          if (_remainingSeconds <= 1) {
            timer.cancel();
            _submitAnswers();
          } else {
            setState(() => _remainingSeconds--);
          }
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to start challenge. Please try again.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitAnswers() async {
    _timer?.cancel();
    setState(() => _submitting = true);

    try {
      final body = {
        'challengeToken': _challengeToken,
        'lessonId': _selectedLessonId,
        'answers': _userAnswers,
      };

      final res = await ApiService().post('/api/ai/daily-challenge/submit', body);
      if (res != null) {
        setState(() {
          _submissionResult = res as Map<String, dynamic>;
          _inChallenge = false;
          _completedToday = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _formatTimer(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return CommonHeaderScaffold(
      subtitle: 'Daily AI Challenge',
      showBackButton: true,
      body: Container(
        color: _bgDark,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _cyan))
            : _inChallenge
                ? _buildQuizView()
                : _completedToday
                    ? _buildCompletedView()
                    : _buildSetupView(),
      ),
    );
  }

  Widget _buildCompletedView() {
    final score = _submissionResult?['score'] ?? _todayAttempt?['score'] ?? _todayAttempt?['todayScore'] ?? 5;
    final total = _submissionResult?['totalQuestions'] ?? _todayAttempt?['totalQuestions'] ?? _todayAttempt?['todayTotal'] ?? 5;
    final points = _submissionResult?['pointsAwarded'] ?? _todayAttempt?['pointsAwarded'] ?? (score * 10);
    final rawReview = _submissionResult?['review'] ?? _todayAttempt?['review'];
    final reviewList = rawReview is List ? rawReview : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_indigo.withValues(alpha: 0.35), _cardDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _indigo.withValues(alpha: 0.5)),
              boxShadow: [
                BoxShadow(
                  color: _indigo.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                const Text('🎉', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                const Text(
                  'Challenge Completed Today!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Great job! You\'ve earned points towards your weekly Leaderboard rank.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatPill('Score', '$score / $total', _cyan),
                    _buildStatPill('Rank Points', '+$points pts', _green),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () => context.push(AppRoutes.leaderboard),
            icon: const Icon(Icons.leaderboard_rounded),
            label: const Text('View Weekly Leaderboard'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _cyan,
              foregroundColor: const Color(0xFF041838),
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '⏳ Next challenge unlocks at midnight (1 per day limit)',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
          ),
          if (reviewList != null && reviewList.isNotEmpty) ...[
            const SizedBox(height: 28),
            Row(
              children: [
                const Icon(Icons.rate_review_outlined, color: _cyan, size: 22),
                const SizedBox(width: 8),
                const Text(
                  'Detailed Answer Review',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _cardDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    '$score / $total Correct',
                    style: const TextStyle(
                      color: _cyan,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...List.generate(reviewList.length, (i) {
              final q = reviewList[i] is Map ? reviewList[i] as Map<String, dynamic> : <String, dynamic>{};
              return _buildQuestionReviewCard(q, i);
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildQuestionReviewCard(Map<String, dynamic> q, int index) {
    final questionText = q['question']?.toString() ?? 'Question ${index + 1}';
    final rawOptions = q['options'] is List ? q['options'] as List<dynamic> : <dynamic>[];
    final correctIndex = (q['correctIndex'] as num?)?.toInt() ?? 0;
    final userChoice = (q['userChoice'] as num?)?.toInt();
    final isCorrect = q['isCorrect'] == true;
    final unanswered = userChoice == null;
    final explanation = q['explanation']?.toString() ?? '';

    final tone = isCorrect ? _green : (unanswered ? Colors.white54 : _red);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardDark.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCorrect ? _green.withValues(alpha: 0.4) : _red.withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildReviewPill('Q${index + 1}', _cyan),
              const SizedBox(width: 8),
              _buildReviewPill(
                isCorrect ? 'Correct' : (unanswered ? 'Not Answered' : 'Incorrect'),
                tone,
              ),
              const Spacer(),
              Icon(
                isCorrect
                    ? Icons.check_circle_rounded
                    : (unanswered ? Icons.help_outline_rounded : Icons.cancel_rounded),
                color: tone,
                size: 22,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            questionText,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(rawOptions.length, (optIdx) {
            final optText = rawOptions[optIdx]?.toString() ?? '';
            final isKey = optIdx == correctIndex;
            final isPicked = optIdx == userChoice;

            Color bg = Colors.transparent;
            Color border = Colors.white12;
            if (isKey) {
              bg = _green.withValues(alpha: 0.18);
              border = _green;
            } else if (isPicked) {
              bg = _red.withValues(alpha: 0.18);
              border = _red;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border, width: (isKey || isPicked) ? 1.5 : 1),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${String.fromCharCode(65 + optIdx)}.',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: (isKey || isPicked) ? Colors.white : Colors.white60,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        optText,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.35,
                          color: (isKey || isPicked) ? Colors.white : Colors.white70,
                          fontWeight: (isKey || isPicked) ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (isPicked && isKey) ...[
                      const SizedBox(width: 8),
                      _buildReviewBadge('Your answer ✓', _green),
                    ] else if (isPicked && !isKey) ...[
                      const SizedBox(width: 8),
                      _buildReviewBadge('Your answer ✗', _red),
                    ] else if (isKey && !isPicked) ...[
                      const SizedBox(width: 8),
                      _buildReviewBadge('Correct answer', _green),
                    ],
                  ],
                ),
              ),
            );
          }),
          if (explanation.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF061A3C),
                borderRadius: BorderRadius.circular(12),
                border: const Border(left: BorderSide(color: _cyan, width: 3.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lightbulb_outline_rounded, color: _cyan, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'EXPLANATION',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _cyan,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    explanation,
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
        ],
      ),
    );
  }

  Widget _buildReviewPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _buildReviewBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildStatPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF071D43),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSetupView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E1B4B), Color(0xFF0C2B64)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _cyan.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _cyan.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.psychology_rounded, color: _cyan, size: 28),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Daily Sprint',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Test your grasp on today\'s lessons with 5 AI-crafted questions. Earn up to +50 points on the Leaderboard!',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Course Picker
          const Text('1. Select Course', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: _cardDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedCourseId,
                isExpanded: true,
                dropdownColor: const Color(0xFF092350),
                hint: const Text('Choose a course', style: TextStyle(color: Colors.white54, fontSize: 13.5)),
                icon: const Icon(Icons.arrow_drop_down, color: _cyan),
                items: _courses.map<DropdownMenuItem<int>>((c) {
                  return DropdownMenuItem<int>(
                    value: c['id'] as int,
                    child: Text(c['title'] as String, style: const TextStyle(color: Colors.white, fontSize: 13.5)),
                  );
                }).toList(),
                onChanged: (id) {
                  if (id != null) _loadCourseModules(id);
                },
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Lesson Picker
          if (_selectedCourseId != null) ...[
            const Text('2. Select Lesson (by Module)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            _loadingModules
                ? const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: _cyan)))
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: _cardDark,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedLessonId,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF092350),
                        hint: const Text('All Course Topics (or pick lesson)', style: TextStyle(color: Colors.white54, fontSize: 13.5)),
                        icon: const Icon(Icons.arrow_drop_down, color: _cyan),
                        items: _buildLessonDropdownItems(),
                        onChanged: (id) => setState(() => _selectedLessonId = id),
                      ),
                    ),
                  ),
            const SizedBox(height: 18),
          ],

          // Difficulty Picker
          const Text('3. Difficulty Level', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: _cardDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedDifficulty,
                isExpanded: true,
                dropdownColor: const Color(0xFF092350),
                icon: const Icon(Icons.arrow_drop_down, color: _cyan),
                items: const [
                  DropdownMenuItem(
                    value: 'low',
                    child: Text('Low / Basic (Foundational - Recommended for B.Tech)', style: TextStyle(color: Colors.white, fontSize: 13.5)),
                  ),
                  DropdownMenuItem(
                    value: 'medium',
                    child: Text('Medium / Intermediate (Core concepts & practical logic)', style: TextStyle(color: Colors.white, fontSize: 13.5)),
                  ),
                  DropdownMenuItem(
                    value: 'critical',
                    child: Text('Critical / Advanced (Deep algorithmic & edge cases)', style: TextStyle(color: Colors.white, fontSize: 13.5)),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedDifficulty = val);
                },
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Start Button
          ElevatedButton(
            onPressed: _startChallenge,
            style: ElevatedButton.styleFrom(
              backgroundColor: _cyan,
              foregroundColor: const Color(0xFF041838),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bolt_rounded, size: 20),
                SizedBox(width: 8),
                Text('Start AI Challenge (5 Questions)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<DropdownMenuItem<int>> _buildLessonDropdownItems() {
    final items = <DropdownMenuItem<int>>[];
    for (final mod in _modules) {
      final lessons = mod['lessons'] as List<dynamic>? ?? [];
      for (final l in lessons) {
        items.add(
          DropdownMenuItem<int>(
            value: l['id'] as int,
            child: Text(
              '${mod['title']} > ${l['title']}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        );
      }
    }
    return items;
  }

  Widget _buildQuizView() {
    if (_questions.isEmpty) {
      return const Center(child: Text('No questions available', style: TextStyle(color: Colors.white70)));
    }

    final q = _questions[_currentQuestionIndex] as Map<String, dynamic>;
    final qText = q['question']?.toString() ?? '';
    final options = (q['options'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final selectedOption = _userAnswers[_currentQuestionIndex.toString()];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timer and Progress Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _cardDark,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  'Q ${_currentQuestionIndex + 1} of ${_questions.length}',
                  style: const TextStyle(color: _cyan, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _remainingSeconds < 60 ? Colors.red.withValues(alpha: 0.2) : _cardDark,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _remainingSeconds < 60 ? Colors.red : Colors.white12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 16, color: _remainingSeconds < 60 ? Colors.red : Colors.white70),
                    const SizedBox(width: 6),
                    Text(
                      _formatTimer(_remainingSeconds),
                      style: TextStyle(
                        color: _remainingSeconds < 60 ? Colors.red : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Question Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _cardDark,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white12),
            ),
            child: Text(
              qText,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, height: 1.4),
            ),
          ),
          const SizedBox(height: 20),

          // Options List
          Expanded(
            child: ListView.builder(
              itemCount: options.length,
              itemBuilder: (context, idx) {
                final isSelected = selectedOption == idx;
                final letter = String.fromCharCode(65 + idx);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _userAnswers[_currentQuestionIndex.toString()] = idx;
                      });
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected ? _cyan.withValues(alpha: 0.18) : _cardDark.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? _cyan : Colors.white.withValues(alpha: 0.08),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: isSelected ? _cyan : Colors.white12,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              letter,
                              style: TextStyle(
                                color: isSelected ? const Color(0xFF041838) : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              options[idx],
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Navigation buttons
          SafeArea(
            top: false,
            bottom: true,
            child: Row(
              children: [
                if (_currentQuestionIndex > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _currentQuestionIndex--),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Previous'),
                    ),
                  ),
                if (_currentQuestionIndex > 0) const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submitting
                        ? null
                        : () {
                            if (_currentQuestionIndex < _questions.length - 1) {
                              setState(() => _currentQuestionIndex++);
                            } else {
                              _submitAnswers();
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _cyan,
                      foregroundColor: const Color(0xFF041838),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _submitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF041838)))
                        : Text(
                            _currentQuestionIndex < _questions.length - 1 ? 'Next' : 'Submit Challenge',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
