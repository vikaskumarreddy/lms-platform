import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/common_header.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final int? mentorId;
  final int? batchId;
  const ChatScreen({super.key, this.mentorId, this.batchId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String _selectedType = 'TEXT'; // TEXT, CODE, ANNOUNCEMENT
  int _targetBatchId = 1;
  int? _currentUserId;
  Timer? _pollTimer;

  // App Dark Navy Theme Constants matching rest of app
  static const _bgDark = Color(0xFF071D43);
  static const _cardDark = Color(0xFF0C2B64);
  static const _surfaceDark = Color(0xFF0A2252);
  static const _cyan = Color(0xFF27D9D3);
  static const _green = Color(0xFF10B981);
  static const _amber = Color(0xFFF59E0B);
  static const _navyText = Color(0xFF041838);

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  Future<void> _initChat() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getInt('userId');
    final storedBatchId = prefs.getInt('batchId');
    _targetBatchId = widget.batchId ?? storedBatchId ?? widget.mentorId ?? 1;

    await _fetchMessages(showLoading: true);

    // Real-time sync poll every 3 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        _fetchMessages(showLoading: false);
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages({bool showLoading = false}) async {
    if (showLoading) setState(() => _loading = true);
    try {
      final list = await _apiService.getBatchChatMessages(_targetBatchId);
      if (mounted) {
        final hadNewMessages = list.length > _messages.length;
        setState(() {
          _messages = list;
          _loading = false;
        });
        if (hadNewMessages) {
          _scrollToBottom();
        }
      }
    } catch (e) {
      if (mounted && showLoading) {
        setState(() => _loading = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      final saved = await _apiService.sendBatchChatMessage(
        _targetBatchId,
        content: text,
        messageType: _selectedType,
      );
      _messageController.clear();
      if (mounted) {
        setState(() {
          _messages.add(saved);
          _sending = false;
          _selectedType = 'TEXT';
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  String _formatTime(dynamic dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr.toString()).toLocal();
      final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final m = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$h:$m $ampm';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate bottom padding so input bar is never obscured by the bottom navigation bar
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final systemBottom = MediaQuery.of(context).padding.bottom;
    final isNavBarHidden = ref.watch(shellNavBarHiddenProvider);
    final double composeBottomPadding = bottomInset > 0
        ? 8.0
        : (isNavBarHidden ? math.max(systemBottom + 8, 16.0) : 100.0);

    return CommonHeaderScaffold(
      subtitle: 'Batch Community',
      showBackButton: true,
      backgroundColor: _bgDark,
      body: Column(
        children: [
          // Live status bar in dark theme
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _surfaceDark.withValues(alpha: 0.85),
              border: const Border(
                bottom: BorderSide(color: Colors.white12, width: 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: _green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Connected to Batch Channel',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _cyan,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _cyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _cyan.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'Real-time Active',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: _cyan,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Messages list
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(_cyan),
                    ),
                  )
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.forum_outlined,
                              size: 54,
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No messages in this batch channel yet',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ask a doubt or share a snippet below!',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.45),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          return _buildMessageBubble(msg);
                        },
                      ),
          ),

          // Message Type Selector & Compose Bar (Safe against bottom navbar)
          Container(
            padding: EdgeInsets.fromLTRB(12, 10, 12, composeBottomPadding),
            decoration: BoxDecoration(
              color: _cardDark,
              border: const Border(
                top: BorderSide(color: Colors.white12, width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Type selector chips
                Row(
                  children: [
                    _typeChip('TEXT', '💬 Text'),
                    const SizedBox(width: 8),
                    _typeChip('CODE', '💻 Code'),
                    const SizedBox(width: 8),
                    _typeChip('ANNOUNCEMENT', '📢 Note'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        minLines: 1,
                        maxLines: _selectedType == 'CODE' ? 6 : 4,
                        cursorColor: _cyan,
                        style: _selectedType == 'CODE'
                            ? const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                                color: Colors.white,
                              )
                            : const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                              ),
                        decoration: InputDecoration(
                          hintText: _selectedType == 'CODE'
                              ? 'Paste code snippet here...'
                              : (_selectedType == 'ANNOUNCEMENT'
                                  ? 'Share announcement or note...'
                                  : 'Ask doubt or message batch...'),
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: const Color(0xFF071D43),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: _cyan,
                      child: IconButton(
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: _navyText,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: _navyText,
                                size: 20,
                              ),
                        onPressed: _sending ? null : _sendMessage,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeChip(String type, String label) {
    final selected = _selectedType == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? _cyan : const Color(0xFF071D43),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _cyan : Colors.white12,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? _navyText : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final senderId = msg['senderId'];
    final isMe = _currentUserId != null && senderId == _currentUserId;
    final messageType = (msg['messageType'] ?? 'TEXT').toString().toUpperCase();
    final senderName = msg['senderName'] ?? (isMe ? 'You' : 'Classmate');
    final senderRole = (msg['senderRole'] ?? 'STUDENT').toString().toUpperCase();
    final isFaculty = senderRole == 'FACULTY' || senderRole == 'ADMIN' || senderRole == 'SUPER_ADMIN';
    final timeStr = _formatTime(msg['createdAt']);
    final content = msg['content'] ?? '';

    // ANNOUNCEMENT BANNER
    if (messageType == 'ANNOUNCEMENT') {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF2E2205),
          border: Border.all(color: _amber, width: 1.2),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('📢', style: TextStyle(fontSize: 15)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ANNOUNCEMENT • $senderName ($senderRole)',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _amber,
                    ),
                  ),
                ),
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: _amber.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFFFEF3C7),
                height: 1.45,
              ),
            ),
          ],
        ),
      );
    }

    // CODE SNIPPET
    if (messageType == 'CODE') {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          width: MediaQuery.of(context).size.width * 0.88,
          decoration: BoxDecoration(
            color: const Color(0xFF031024),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isMe ? _cyan.withValues(alpha: 0.4) : Colors.white12,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Code Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFF061733),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.code_rounded, color: _cyan, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '$senderName ($senderRole)',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      timeStr,
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: content));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Code copied to clipboard!'),
                            duration: Duration(seconds: 1),
                            backgroundColor: _cyan,
                          ),
                        );
                      },
                      child: const Icon(Icons.copy_rounded, color: _cyan, size: 15),
                    ),
                  ],
                ),
              ),
              // Code Body
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  content,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                    color: Color(0xFF38BDF8),
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // REGULAR TEXT BUBBLE
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe
              ? _cyan
              : (isFaculty ? const Color(0xFF10367A) : _cardDark),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: isMe
              ? null
              : Border.all(
                  color: isFaculty ? _cyan.withValues(alpha: 0.4) : Colors.white12,
                ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      senderName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isFaculty ? _cyan : Colors.white70,
                      ),
                    ),
                    if (isFaculty)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: _cyan.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: _cyan.withValues(alpha: 0.5)),
                        ),
                        child: const Text(
                          'FACULTY',
                          style: TextStyle(
                            fontSize: 8.5,
                            color: _cyan,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            Text(
              content,
              style: TextStyle(
                fontSize: 13.5,
                color: isMe ? _navyText : Colors.white,
                fontWeight: isMe ? FontWeight.w500 : FontWeight.normal,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                timeStr,
                style: TextStyle(
                  fontSize: 10,
                  color: isMe ? _navyText.withValues(alpha: 0.6) : Colors.white38,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}