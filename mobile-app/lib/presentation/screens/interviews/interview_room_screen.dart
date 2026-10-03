import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/routes.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/mobile_auth_service.dart';
import 'widgets/interview_video_pane.dart';
import 'widgets/interview_code_editor_pane.dart';
import 'widgets/interview_problem_pane.dart';
import 'widgets/interview_evaluation_pane.dart';
import 'widgets/interview_chat_pane.dart';
import 'widgets/interview_candidate_profile_pane.dart';

/// 1-on-1 Realtime Interview Room (powered by WebRTC video/audio & live collaborative coding).
class InterviewRoomScreen extends StatefulWidget {
  final String roomCode;

  const InterviewRoomScreen({
    super.key,
    required this.roomCode,
  });

  @override
  State<InterviewRoomScreen> createState() => _InterviewRoomScreenState();
}

class _InterviewRoomScreenState extends State<InterviewRoomScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();

  bool _loading = true;
  Map<String, dynamic>? _roomData;
  List<Map<String, dynamic>> _questions = [];

  // Active coding question
  String _problemTitle = 'Two Sum - Target Pair';
  String _problemDifficulty = 'Easy';
  String _problemCategory = 'Data Structures & Algorithms';
  String _problemDescription = '';
  String _starterCodeJava = '';

  // Active workbench tab for Desktop (0: Code, 1: Problem, 2: Rubric, 3: Chat)
  int _activeWorkbenchTab = 0;

  // Active view for Mobile (0: Code, 1: Video, 2: Problem, 3: Chat, 4: Rubric)
  int _mobileActiveTab = 0;
  bool _showMobileMiniVideo = false;

  bool _isInterviewer = false;
  bool _roleInitialized = false;

  // Presence & Active Participants
  bool _interviewerOnline = false;
  bool _candidateOnline = false;
  int _activeCount = 1;
  Timer? _presenceTimer;

  // Call timer (45 minutes countdown)
  int _secondsRemaining = 45 * 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadRoomDetails();
    _startTimer();
    _startPresencePolling();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_roleInitialized) {
      _roleInitialized = true;
      _detectUserRole();
    }
  }

  void _detectUserRole() {
    String? roleParam;
    try {
      final uri = GoRouterState.of(context).uri;
      roleParam = uri.queryParameters['role']?.toLowerCase();
    } catch (_) {}

    if (roleParam == null || roleParam.isEmpty) {
      try {
        roleParam = Uri.base.queryParameters['role']?.toLowerCase();
      } catch (_) {}
    }

    if (roleParam == null || roleParam.isEmpty) {
      try {
        final frag = Uri.base.fragment;
        if (frag.contains('role=')) {
          final uriFrag = Uri.parse(frag.startsWith('/') ? frag : '/$frag');
          roleParam = uriFrag.queryParameters['role']?.toLowerCase();
        }
      } catch (_) {}
    }

    if (roleParam != null && roleParam.isNotEmpty) {
      if (roleParam == 'candidate' || roleParam == 'student') {
        setState(() {
          _isInterviewer = false;
          _activeWorkbenchTab = 0;
          _mobileActiveTab = 0;
        });
        return;
      } else if (roleParam == 'interviewer' || roleParam == 'faculty' || roleParam == 'admin') {
        setState(() {
          _isInterviewer = true;
        });
        return;
      }
    }

    // Fallback to logged in user role
    MobileAuthService().getUser().then((user) {
      if (!mounted) return;
      if (user != null) {
        final r = (user.role ?? '').toUpperCase();
        final isFacultyOrAdmin = r == 'FACULTY' || r == 'ADMIN' || r == 'SUPER_ADMIN' || r == 'INSTRUCTOR';
        setState(() {
          _isInterviewer = isFacultyOrAdmin;
          if (!_isInterviewer) {
            _activeWorkbenchTab = 0;
            _mobileActiveTab = 0;
          }
        });
      } else {
        setState(() {
          _isInterviewer = false;
        });
      }
    }).catchError((_) {
      if (mounted) {
        setState(() {
          _isInterviewer = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _presenceTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  void _startPresencePolling() {
    _tickPresence();
    _presenceTimer = Timer.periodic(const Duration(seconds: 3), (_) => _tickPresence());
  }

  Future<void> _tickPresence() async {
    final myRole = _isInterviewer ? 'interviewer' : 'candidate';
    final myName = _isInterviewer
        ? (_roomData?['interviewerName'] as String? ?? 'Faculty Interviewer')
        : (_roomData?['candidateName'] as String? ?? 'Student Candidate');

    await _api.updateInterviewPresence(widget.roomCode, role: myRole, name: myName);
    final presence = await _api.getInterviewPresence(widget.roomCode);

    if (!mounted || presence == null) return;

    final wasBothConnected = _interviewerOnline && _candidateOnline;
    final intOnline = presence['interviewerOnline'] == true;
    final candOnline = presence['candidateOnline'] == true;
    final count = (presence['activeCount'] as num?)?.toInt() ?? 1;

    setState(() {
      _interviewerOnline = intOnline;
      _candidateOnline = candOnline;
      _activeCount = count;
    });

    // Notify when peer enters room
    if (!wasBothConnected && intOnline && candOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isInterviewer ? '🎉 Candidate has entered the room!' : '🎉 Faculty Interviewer has entered the room!',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  String get _formattedTime {
    final minutes = _secondsRemaining ~/ 60;
    final seconds = _secondsRemaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _loadRoomDetails() async {
    setState(() => _loading = true);

    final room = await _api.createOrJoinInterviewRoom(roomCode: widget.roomCode);
    final questions = await _api.getInterviewQuestions();

    if (!mounted) return;

    if (room != null) {
      setState(() {
        _roomData = room;
        _problemTitle = (room['problemTitle'] as String?) ?? 'Two Sum';
        _problemDifficulty = (room['problemDifficulty'] as String?) ?? 'Easy';
        _problemDescription = (room['problemDescription'] as String?) ?? '';
        _questions = questions;
        _loading = false;
      });
    } else {
      setState(() {
        _roomData = {
          'roomCode': widget.roomCode,
          'candidateName': 'Alex Morgan (Student)',
          'interviewerName': 'Dr. Sarah Chen (Faculty)',
          'hmsMeetingUrl': 'https://axisora.app.100ms.live/meeting/${widget.roomCode.toLowerCase()}',
        };
        _problemTitle = 'Two Sum - Target Pair';
        _problemDifficulty = 'Easy';
        _problemDescription = 'Given an array of integers `nums` and an integer `target`, return indices of the two numbers such that they add up to `target`.\n\n```\nInput: nums = [2,7,11,15], target = 9\nOutput: [0,1]\n```';
        _questions = questions;
        _loading = false;
      });
    }
  }

  void _onSelectQuestion(Map<String, dynamic> q) {
    setState(() {
      _problemTitle = (q['title'] as String?) ?? _problemTitle;
      _problemDifficulty = (q['difficulty'] as String?) ?? 'Medium';
      _problemCategory = (q['category'] as String?) ?? 'DSA';
      _problemDescription = (q['description'] as String?) ?? '';
      _starterCodeJava = (q['starterCodeJava'] as String?) ?? '';
      _activeWorkbenchTab = 0;
      _mobileActiveTab = 0;
    });
  }

  Future<Map<String, dynamic>?> _handleRunCode(String language, String code, String? input) async {
    return await _api.executeInterviewCode(
      widget.roomCode,
      language: language,
      code: code,
      input: input,
    );
  }

  Future<bool> _handleSubmitEvaluation(Map<String, dynamic> eval) async {
    final res = await _api.submitInterviewEvaluation(widget.roomCode, eval);
    return res != null && res['success'] == true;
  }

  void _copyRoomCode() {
    Clipboard.setData(ClipboardData(text: widget.roomCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Room code copied: ${widget.roomCode}'),
        backgroundColor: const Color(0xFF27D9D3),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _confirmLeaveCall() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131D32),
        title: Text('Leave Interview Room?', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to exit the interview studio? Your code and evaluations will be preserved.',
          style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () {
              Navigator.pop(ctx);
              context.go(AppRoutes.interviewHistory);
            },
            child: Text('Leave Room', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFF070F1D), // Axisora Deep Dark Theme
      body: SafeArea(
        child: _loading
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF27D9D3)),
                    const SizedBox(height: 16),
                    Text(
                      'Connecting to Axisora Live Interview Studio...',
                      style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  _buildResponsiveTopBar(isDesktop),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        isDesktop ? 12 : 8,
                        0,
                        isDesktop ? 12 : 8,
                        isDesktop ? 12 : 8,
                      ),
                      child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _showCandidateProfileBottomSheet() {
    final candidateId = (_roomData?['candidateId'] as num?)?.toInt();
    final candidateName = _roomData?['candidateName'] as String?;
    final candidateEmail = _roomData?['candidateEmail'] as String?;
    final batchName = _roomData?['batchName'] as String?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF071120),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.85,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: InterviewCandidateProfilePane(
            candidateId: candidateId,
            candidateName: candidateName,
            candidateEmail: candidateEmail,
            batchName: batchName,
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveTopBar(bool isDesktop) {
    final isConnected = _interviewerOnline && _candidateOnline;

    if (!isDesktop) {
      // Mobile Top Bar: 2 compact rows to prevent any horizontal overflow
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1A2E),
          border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row 1: Brand Logo + Room Code + Profile Button + Role Pill + Leave
            Row(
              children: [
                InkWell(
                  onTap: () => context.go(AppRoutes.home),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF27D9D3), Color(0xFF6366F1)]),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.videocam, color: Colors.white, size: 15),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: _copyRoomCode,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF13223A),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.vpn_key, color: Color(0xFF27D9D3), size: 11),
                        const SizedBox(width: 4),
                        Text(
                          widget.roomCode,
                          style: GoogleFonts.firaCode(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 3),
                        const Icon(Icons.copy, color: Colors.white54, size: 11),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Candidate Profile',
                  onPressed: _showCandidateProfileBottomSheet,
                  icon: const Icon(Icons.person_pin_rounded, color: Color(0xFF27D9D3), size: 18),
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  padding: EdgeInsets.zero,
                ),
                const Spacer(),
                // Role badge
                InkWell(
                  onTap: () {
                    setState(() {
                      _isInterviewer = !_isInterviewer;
                      if (!_isInterviewer) {
                        if (_activeWorkbenchTab == 2) _activeWorkbenchTab = 0;
                        if (_mobileActiveTab == 5) _mobileActiveTab = 0;
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: _isInterviewer ? const Color(0xFF6366F1).withOpacity(0.2) : const Color(0xFF27D9D3).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _isInterviewer ? const Color(0xFF6366F1).withOpacity(0.5) : const Color(0xFF27D9D3).withOpacity(0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isInterviewer ? Icons.admin_panel_settings : Icons.school,
                          size: 11,
                          color: _isInterviewer ? const Color(0xFF818CF8) : const Color(0xFF27D9D3),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _isInterviewer ? 'Faculty' : 'Student',
                          style: GoogleFonts.inter(
                            color: _isInterviewer ? const Color(0xFF818CF8) : const Color(0xFF27D9D3),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Leave Call',
                  onPressed: _confirmLeaveCall,
                  icon: const Icon(Icons.logout, color: Color(0xFFEF4444), size: 16),
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Row 2: Live status + Timer
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isConnected ? const Color(0xFF10B981).withOpacity(0.15) : const Color(0xFFF59E0B).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: isConnected ? const Color(0xFF10B981) : const Color(0xFFF59E0B).withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isConnected ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isConnected
                            ? 'Connected (2/2)'
                            : (_activeCount == 0 ? 'Connecting...' : 'Waiting (1/2)'),
                        style: GoogleFonts.inter(
                          color: isConnected ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_outlined, color: Color(0xFFF59E0B), size: 11),
                      const SizedBox(width: 3),
                      Text(
                        _formattedTime,
                        style: GoogleFonts.firaCode(color: const Color(0xFFF59E0B), fontSize: 10.5, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Desktop Top Bar: Single horizontal row
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1A2E),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => context.go(AppRoutes.home),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF27D9D3), Color(0xFF6366F1)]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.videocam, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Axisora Live Interview',
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '1-on-1 Studio',
                      style: GoogleFonts.inter(color: const Color(0xFF27D9D3), fontSize: 10, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: _copyRoomCode,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF13223A),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.vpn_key, color: Color(0xFF27D9D3), size: 12),
                  const SizedBox(width: 4),
                  Text(
                    widget.roomCode,
                    style: GoogleFonts.firaCode(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.copy, color: Colors.white54, size: 12),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Candidate Profile Button
          InkWell(
            onTap: _showCandidateProfileBottomSheet,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_pin_rounded, color: Color(0xFFA5B4FC), size: 13),
                  const SizedBox(width: 4),
                  Text(
                    'Candidate Profile',
                    style: GoogleFonts.inter(color: const Color(0xFFA5B4FC), fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isConnected ? const Color(0xFF10B981).withOpacity(0.15) : const Color(0xFFF59E0B).withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isConnected ? const Color(0xFF10B981) : const Color(0xFFF59E0B).withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isConnected ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  isConnected
                      ? 'Connected (2/2)'
                      : (_activeCount == 0 ? 'Connecting...' : 'Waiting (1/2)'),
                  style: GoogleFonts.inter(
                    color: isConnected ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer_outlined, color: Color(0xFFF59E0B), size: 13),
                const SizedBox(width: 4),
                Text(
                  _formattedTime,
                  style: GoogleFonts.firaCode(color: const Color(0xFFF59E0B), fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF13223A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            padding: const EdgeInsets.all(2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildRoleSwitchButton(
                  title: 'Faculty',
                  icon: Icons.admin_panel_settings,
                  isActive: _isInterviewer,
                  color: const Color(0xFF6366F1),
                  onTap: () {
                    setState(() {
                      _isInterviewer = true;
                    });
                  },
                ),
                _buildRoleSwitchButton(
                  title: 'Student',
                  icon: Icons.school,
                  isActive: !_isInterviewer,
                  color: const Color(0xFF27D9D3),
                  onTap: () {
                    setState(() {
                      _isInterviewer = false;
                      if (_activeWorkbenchTab == 2) _activeWorkbenchTab = 0;
                      if (_mobileActiveTab == 5) _mobileActiveTab = 0;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Leave Call',
            onPressed: _confirmLeaveCall,
            icon: const Icon(Icons.logout, color: Color(0xFFEF4444), size: 18),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: const EdgeInsets.all(6),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSwitchButton({
    required String title,
    required IconData icon,
    required bool isActive,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: isActive ? Border.all(color: color.withOpacity(0.6)) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: isActive ? color : Colors.white60),
            const SizedBox(width: 4),
            Text(
              title,
              style: GoogleFonts.inter(
                color: isActive ? Colors.white : Colors.white60,
                fontSize: 10.5,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    final meetingUrl = _roomData?['hmsMeetingUrl'] as String?;
    final candidateName = _roomData?['candidateName'] as String?;
    final interviewerName = _roomData?['interviewerName'] as String?;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left Column (40% width): Live WebRTC Video Pane + Real-Time Chat
        Expanded(
          flex: 40,
          child: Column(
            children: [
              Expanded(
                flex: 62,
                child: InterviewVideoPane(
                  roomCode: widget.roomCode,
                  meetingUrl: meetingUrl,
                  candidateName: candidateName,
                  interviewerName: interviewerName,
                  isInterviewer: _isInterviewer,
                  onLeaveCall: _confirmLeaveCall,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                flex: 38,
                child: InterviewChatPane(
                  roomCode: widget.roomCode,
                  currentUserName: _isInterviewer ? (interviewerName ?? 'Faculty Interviewer') : (candidateName ?? 'Student Candidate'),
                  isInterviewer: _isInterviewer,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 12),

        // Right Column (60% width): Workbench (Code Editor, Problem Prompt, Scoring Rubric)
        Expanded(
          flex: 60,
          child: Column(
            children: [
              _buildWorkbenchTabBar(isDesktop: true),
              const SizedBox(height: 8),
              Expanded(
                child: _buildActiveWorkbenchContent(_activeWorkbenchTab),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    final meetingUrl = _roomData?['hmsMeetingUrl'] as String?;
    final candidateName = _roomData?['candidateName'] as String?;
    final interviewerName = _roomData?['interviewerName'] as String?;

    return Column(
      children: [
        // Mobile Segmented Tab Navigation Bar (Scrollable, never overflows)
        _buildMobileSegmentedTabs(),

        const SizedBox(height: 8),

        // Optional Mini Video Card when on Code Editor or Problem Prompt
        if (_showMobileMiniVideo && _mobileActiveTab != 1) ...[
          Container(
            height: 140,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF27D9D3).withOpacity(0.3)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  InterviewVideoPane(
                    roomCode: widget.roomCode,
                    meetingUrl: meetingUrl,
                    candidateName: candidateName,
                    interviewerName: interviewerName,
                    isInterviewer: _isInterviewer,
                    onLeaveCall: _confirmLeaveCall,
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: InkWell(
                      onTap: () => setState(() => _showMobileMiniVideo = false),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        // Active Mobile Tab View
        Expanded(
          child: _buildMobileTabContent(),
        ),
      ],
    );
  }

  Widget _buildMobileSegmentedTabs() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1A2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _mobileTabItem(0, 'Code', Icons.code),
            _mobileTabItem(1, 'Video', Icons.videocam),
            _mobileTabItem(2, 'Problem', Icons.description_outlined),
            _mobileTabItem(3, 'Chat', Icons.chat_bubble_outline),
            _mobileTabItem(4, 'Profile', Icons.person_pin_rounded),
            if (_isInterviewer) _mobileTabItem(5, 'Rubric', Icons.grading),

            // Mini Video PiP Toggle Button on Mobile
            if (_mobileActiveTab != 1) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: () => setState(() => _showMobileMiniVideo = !_showMobileMiniVideo),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: _showMobileMiniVideo ? const Color(0xFF27D9D3).withOpacity(0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _showMobileMiniVideo ? const Color(0xFF27D9D3) : Colors.white12,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _showMobileMiniVideo ? Icons.picture_in_picture_alt : Icons.picture_in_picture,
                        size: 13,
                        color: _showMobileMiniVideo ? const Color(0xFF27D9D3) : Colors.white60,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _showMobileMiniVideo ? 'Hide PiP' : 'PiP',
                        style: GoogleFonts.inter(
                          color: _showMobileMiniVideo ? const Color(0xFF27D9D3) : Colors.white60,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _mobileTabItem(int index, String title, IconData icon) {
    final isSelected = _mobileActiveTab == index;
    return InkWell(
      onTap: () => setState(() => _mobileActiveTab = index),
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF27D9D3).withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isSelected ? Border.all(color: const Color(0xFF27D9D3).withOpacity(0.5)) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? const Color(0xFF27D9D3) : Colors.white60,
            ),
            const SizedBox(width: 5),
            Text(
              title,
              style: GoogleFonts.inter(
                color: isSelected ? Colors.white : Colors.white60,
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileTabContent() {
    final meetingUrl = _roomData?['hmsMeetingUrl'] as String?;
    final candidateName = _roomData?['candidateName'] as String?;
    final interviewerName = _roomData?['interviewerName'] as String?;

    switch (_mobileActiveTab) {
      case 0:
        return InterviewCodeEditorPane(
          roomCode: widget.roomCode,
          initialLanguage: (_roomData?['codeLanguage'] as String?) ?? 'java',
          initialCode: _starterCodeJava.isNotEmpty
              ? _starterCodeJava
              : ((_roomData?['submittedCode'] as String?) ?? ''),
          onRunCode: _handleRunCode,
        );
      case 1:
        return InterviewVideoPane(
          roomCode: widget.roomCode,
          meetingUrl: meetingUrl,
          candidateName: candidateName,
          interviewerName: interviewerName,
          isInterviewer: _isInterviewer,
          onLeaveCall: _confirmLeaveCall,
        );
      case 2:
        return InterviewProblemPane(
          title: _problemTitle,
          difficulty: _problemDifficulty,
          category: _problemCategory,
          description: _problemDescription,
          availableQuestions: _questions,
          onSelectQuestion: _onSelectQuestion,
        );
      case 3:
        return InterviewChatPane(
          roomCode: widget.roomCode,
          currentUserName: _isInterviewer ? (interviewerName ?? 'Faculty Interviewer') : (candidateName ?? 'Student Candidate'),
          isInterviewer: _isInterviewer,
        );
      case 4:
        return InterviewCandidateProfilePane(
          candidateId: (_roomData?['candidateId'] as num?)?.toInt(),
          candidateName: _roomData?['candidateName'] as String?,
          candidateEmail: _roomData?['candidateEmail'] as String?,
          batchName: _roomData?['batchName'] as String?,
        );
      case 5:
        if (!_isInterviewer) {
          return InterviewCodeEditorPane(
            roomCode: widget.roomCode,
            initialLanguage: (_roomData?['codeLanguage'] as String?) ?? 'java',
            initialCode: _starterCodeJava.isNotEmpty
                ? _starterCodeJava
                : ((_roomData?['submittedCode'] as String?) ?? ''),
            onRunCode: _handleRunCode,
          );
        }
        return InterviewEvaluationPane(
          roomCode: widget.roomCode,
          candidateName: _roomData?['candidateName'] as String?,
          initialProblemSolving: (_roomData?['problemSolvingScore'] as num?)?.toInt() ?? 4,
          initialTechnical: (_roomData?['technicalCompetencyScore'] as num?)?.toInt() ?? 4,
          initialCodeQuality: (_roomData?['codeQualityScore'] as num?)?.toInt() ?? 3,
          initialCommunication: (_roomData?['communicationScore'] as num?)?.toInt() ?? 4,
          initialDecision: (_roomData?['hiringDecision'] as String?) ?? 'HIRE',
          initialNotes: (_roomData?['interviewerNotes'] as String?) ?? '',
          onSubmit: _handleSubmitEvaluation,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildWorkbenchTabBar({required bool isDesktop}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1A2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          _workbenchTabItem(0, _isInterviewer ? 'Code Workspace' : 'Code Editor', Icons.code),
          _workbenchTabItem(1, 'Problem Prompt', Icons.description_outlined),
          if (_isInterviewer) _workbenchTabItem(2, 'Scoring Rubric', Icons.grading),
          _workbenchTabItem(3, 'Candidate Profile', Icons.person_pin_rounded),
          _workbenchTabItem(4, 'Chat & Notes', Icons.chat_bubble_outline),
        ],
      ),
    );
  }

  Widget _workbenchTabItem(int index, String title, IconData icon) {
    final isSelected = _activeWorkbenchTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeWorkbenchTab = index),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF27D9D3).withOpacity(0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected ? Border.all(color: const Color(0xFF27D9D3).withOpacity(0.4)) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? const Color(0xFF27D9D3) : Colors.white60,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    color: isSelected ? Colors.white : Colors.white60,
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveWorkbenchContent(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return InterviewCodeEditorPane(
          roomCode: widget.roomCode,
          initialLanguage: (_roomData?['codeLanguage'] as String?) ?? 'java',
          initialCode: _starterCodeJava.isNotEmpty
              ? _starterCodeJava
              : ((_roomData?['submittedCode'] as String?) ?? ''),
          onRunCode: _handleRunCode,
        );
      case 1:
        return InterviewProblemPane(
          title: _problemTitle,
          difficulty: _problemDifficulty,
          category: _problemCategory,
          description: _problemDescription,
          availableQuestions: _questions,
          onSelectQuestion: _onSelectQuestion,
        );
      case 2:
        if (!_isInterviewer) {
          // Candidates do not have access to the rubric; default to editor
          return InterviewCodeEditorPane(
            roomCode: widget.roomCode,
            initialLanguage: (_roomData?['codeLanguage'] as String?) ?? 'java',
            initialCode: _starterCodeJava.isNotEmpty
                ? _starterCodeJava
                : ((_roomData?['submittedCode'] as String?) ?? ''),
            onRunCode: _handleRunCode,
          );
        }
        return InterviewEvaluationPane(
          roomCode: widget.roomCode,
          candidateName: _roomData?['candidateName'] as String?,
          initialProblemSolving: (_roomData?['problemSolvingScore'] as num?)?.toInt() ?? 4,
          initialTechnical: (_roomData?['technicalCompetencyScore'] as num?)?.toInt() ?? 4,
          initialCodeQuality: (_roomData?['codeQualityScore'] as num?)?.toInt() ?? 3,
          initialCommunication: (_roomData?['communicationScore'] as num?)?.toInt() ?? 4,
          initialDecision: (_roomData?['hiringDecision'] as String?) ?? 'HIRE',
          initialNotes: (_roomData?['interviewerNotes'] as String?) ?? '',
          onSubmit: _handleSubmitEvaluation,
        );
      case 3:
        return InterviewCandidateProfilePane(
          candidateId: (_roomData?['candidateId'] as num?)?.toInt(),
          candidateName: _roomData?['candidateName'] as String?,
          candidateEmail: _roomData?['candidateEmail'] as String?,
          batchName: _roomData?['batchName'] as String?,
        );
      case 4:
      default:
        final candidateName = _roomData?['candidateName'] as String?;
        final interviewerName = _roomData?['interviewerName'] as String?;
        return InterviewChatPane(
          roomCode: widget.roomCode,
          currentUserName: _isInterviewer ? (interviewerName ?? 'Faculty Interviewer') : (candidateName ?? 'Student Candidate'),
          isInterviewer: _isInterviewer,
        );
    }
  }
}
