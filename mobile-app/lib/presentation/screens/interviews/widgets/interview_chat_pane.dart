import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lms_student_app/core/services/api_service.dart';

/// In-Call Chat & Q&A Pane for 1-on-1 Interviews.
class InterviewChatPane extends StatefulWidget {
  final String roomCode;
  final String currentUserName;
  final bool isInterviewer;

  const InterviewChatPane({
    super.key,
    required this.roomCode,
    this.currentUserName = 'You',
    this.isInterviewer = false,
  });

  @override
  State<InterviewChatPane> createState() => _InterviewChatPaneState();
}

class _InterviewChatPaneState extends State<InterviewChatPane> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ApiService _api = ApiService();
  Timer? _chatPollTimer;

  final List<Map<String, dynamic>> _messages = [
    {
      'sender': 'System',
      'role': 'bot',
      'text': 'Welcome to the 1-on-1 Interview Room! WebRTC audio & HD video connected.',
      'time': 'Just now',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _chatPollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _loadMessages());
  }

  Future<void> _loadMessages() async {
    final remoteMsgs = await _api.getInterviewChat(widget.roomCode);
    if (!mounted || remoteMsgs.isEmpty) return;
    setState(() {
      for (final rm in remoteMsgs) {
        final text = rm['text'] ?? rm['message'] ?? '';
        final sender = rm['sender'] ?? 'User';
        if (!_messages.any((m) => m['id'] == rm['id'] || (m['text'] == text && m['sender'] == sender))) {
          _messages.add({
            'id': rm['id'],
            'sender': sender,
            'role': rm['role'] ?? 'candidate',
            'text': text,
            'time': rm['time'] ?? 'Just now',
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _chatPollTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage([String? presetText]) {
    final text = (presetText ?? _messageController.text).trim();
    if (text.isEmpty) return;

    final now = DateTime.now();
    final timeStr = '${now.hour % 12 == 0 ? 12 : now.hour % 12}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';

    final newMsg = {
      'sender': widget.currentUserName,
      'role': widget.isInterviewer ? 'interviewer' : 'candidate',
      'text': text,
      'time': timeStr,
    };

    setState(() {
      _messages.add(newMsg);
      if (presetText == null) {
        _messageController.clear();
      }
    });

    _api.sendInterviewChat(widget.roomCode, newMsg);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
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
            // Chat Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF111E33),
                border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_outline, color: Color(0xFF27D9D3), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'In-Call Live Chat',
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF10B981)),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Online',
                    style: GoogleFonts.inter(color: Colors.white60, fontSize: 11),
                  ),
                ],
              ),
            ),

            // Message List
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isBot = msg['role'] == 'bot';
                  final isSelf = msg['sender'] == widget.currentUserName;

                  if (isBot) {
                    return Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A2639),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withOpacity(0.06)),
                        ),
                        child: Text(
                          msg['text'] as String,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(color: Colors.white70, fontSize: 11),
                        ),
                      ),
                    );
                  }

                  final bubbleColor = isSelf
                      ? const Color(0xFF27D9D3).withOpacity(0.2)
                      : const Color(0xFF6366F1).withOpacity(0.2);
                  final borderColor = isSelf
                      ? const Color(0xFF27D9D3).withOpacity(0.5)
                      : const Color(0xFF6366F1).withOpacity(0.5);

                  return Align(
                    alignment: isSelf ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 280),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor, width: 0.8),
                      ),
                      child: Column(
                        crossAxisAlignment: isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                msg['sender'] as String,
                                style: GoogleFonts.inter(
                                  color: isSelf ? const Color(0xFF27D9D3) : const Color(0xFF818CF8),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                msg['time'] as String,
                                style: GoogleFonts.inter(color: Colors.white38, fontSize: 9.5),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            msg['text'] as String,
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 12, height: 1.35),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Quick Prompt Chips
            Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              color: const Color(0xFF09121F),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _quickChip('Can you hear me fine?'),
                  _quickChip('Let me share the algorithm approach.'),
                  _quickChip('Running the test cases now.'),
                  _quickChip('What are the edge constraints?'),
                ],
              ),
            ),

            // Input Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF111E33),
                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Type a message to the room...',
                        hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 12),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        filled: true,
                        fillColor: const Color(0xFF0D1726),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _sendMessage(),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF27D9D3),
                      ),
                      child: const Icon(Icons.send, color: Color(0xFF071120), size: 16),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickChip(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 6, top: 4, bottom: 4),
      child: InkWell(
        onTap: () => _sendMessage(text),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF16233B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Text(
            text,
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 10),
          ),
        ),
      ),
    );
  }
}
