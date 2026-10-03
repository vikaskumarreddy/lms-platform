import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'interview_video_view_stub.dart'
    if (dart.library.html) 'interview_video_view_web.dart';

/// Realtime WebRTC Video Calling Pane for 1-on-1 Interviews.
/// Directly interfaces with browser camera and microphone streams via WebRTC
/// and integrates with the Axisora interview signaling backend.
class InterviewVideoPane extends StatefulWidget {
  final String roomCode;
  final String? meetingUrl;
  final String? candidateName;
  final String? interviewerName;
  final bool isInterviewer;
  final VoidCallback onLeaveCall;

  const InterviewVideoPane({
    super.key,
    required this.roomCode,
    this.meetingUrl,
    this.candidateName,
    this.interviewerName,
    this.isInterviewer = false,
    required this.onLeaveCall,
  });

  @override
  State<InterviewVideoPane> createState() => _InterviewVideoPaneState();
}

class _InterviewVideoPaneState extends State<InterviewVideoPane> {
  bool _isLoading = true;
  Timer? _loadingTimer;

  String get _viewId => 'axisora-interview-video-${widget.roomCode}-${widget.isInterviewer ? "interviewer" : "candidate"}';

  String get _callUrl {
    final role = widget.isInterviewer ? 'interviewer' : 'candidate';
    final name = Uri.encodeComponent(
      widget.isInterviewer
          ? (widget.interviewerName ?? 'Lead Interviewer')
          : (widget.candidateName ?? 'Candidate'),
    );
    return '/interview_call.html?roomCode=${widget.roomCode}&role=$role&name=$name&v=20260928_v4';
  }

  @override
  void initState() {
    super.initState();
    _loadingTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    });
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF071120),
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
        child: Stack(
          children: [
            buildInterviewVideoView(
              url: _callUrl,
              viewId: _viewId,
              onLoaded: () {
                if (mounted) setState(() => _isLoading = false);
              },
            ),

            if (_isLoading)
              Container(
                color: const Color(0xFF071120),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Color(0xFF27D9D3)),
                      const SizedBox(height: 12),
                      Text(
                        'Initializing WebRTC Camera & Mic...',
                        style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
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
}
