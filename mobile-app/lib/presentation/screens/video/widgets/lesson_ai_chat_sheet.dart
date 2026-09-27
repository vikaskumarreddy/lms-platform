import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/api_service.dart';
import '../../../../data/models/lesson.dart';

/// Interactive AI Tutor Chatbot sheet for a lesson.
/// Uses the lesson's PDF notes + broad academic knowledge as context.
class LessonAiChatSheet extends ConsumerStatefulWidget {
  final Lesson lesson;
  final String? localPdfPath;

  const LessonAiChatSheet({
    super.key,
    required this.lesson,
    this.localPdfPath,
  });

  /// Helper to open the AI Tutor sheet as a modal bottom sheet.
  static Future<void> show(BuildContext context, Lesson lesson, {String? localPdfPath}) {
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => LessonAiChatSheet(
        lesson: lesson,
        localPdfPath: localPdfPath,
      ),
    );
  }

  @override
  ConsumerState<LessonAiChatSheet> createState() => _LessonAiChatSheetState();
}

class _LessonAiChatSheetState extends ConsumerState<LessonAiChatSheet> {
  static const _bgNavy = Color(0xFF071D43);
  static const _cardNavy = Color(0xFF0C2B64);
  static const _borderNavy = Color(0xFF1E3A8A);
  static const _cyan = Color(0xFF27D9D3);
  static const _indigo = Color(0xFF6366F1);

  final ApiService _api = ApiService();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  bool _loading = true;
  bool _sending = false;
  bool _isExpanded = false;
  bool _showScrollToBottom = false;
  bool _showScrollToTop = false;
  String? _error;

  int _questionLimit = 100;
  int _questionsAsked = 0;
  int _questionsRemaining = 100;
  bool _isLimitReached = false;

  final List<Map<String, String>> _messages = [];

  final List<String> _starterSuggestions = const [
    '📝 Summarize this lesson',
    '💡 Key takeaways & formulas',
    '❓ Give me 3 practice questions',
    '🔍 Explain core concepts step-by-step',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadHistory();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final curr = _scrollController.offset;
    final showBottom = (max - curr) > 160;
    final showTop = curr > 160;
    if (showBottom != _showScrollToBottom || showTop != _showScrollToTop) {
      setState(() {
        _showScrollToBottom = showBottom;
        _showScrollToTop = showTop;
      });
    }
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _api.getLessonAiChat(widget.lesson.id);
      if (!mounted) return;

      if (data != null) {
        _questionLimit = (data['questionLimit'] as num?)?.toInt() ?? 100;
        _questionsAsked = (data['questionsAsked'] as num?)?.toInt() ?? 0;
        _questionsRemaining = (data['questionsRemaining'] as num?)?.toInt() ?? (_questionLimit - _questionsAsked);
        _isLimitReached = data['isLimitReached'] == true || _questionsRemaining <= 0;

        _messages.clear();
        final rawMsgs = data['messages'];
        if (rawMsgs is List) {
          for (final m in rawMsgs) {
            if (m is Map) {
              _messages.add({
                'role': m['role']?.toString() ?? 'user',
                'content': m['content']?.toString() ?? '',
              });
            }
          }
        }
      }
    } catch (e) {
      if (mounted) _error = e.toString();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _scrollToBottom(animated: false);
      }
    }
  }

  Future<void> _sendMessage([String? presetText]) async {
    final text = presetText ?? _textController.text.trim();
    if (text.isEmpty || _sending || _isLimitReached) return;

    if (presetText == null) {
      _textController.clear();
    }

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _sending = true;
      _error = null;
    });

    _scrollToBottom();

    try {
      final res = await _api.askLessonAiQuestion(
        widget.lesson.id,
        text,
      );

      if (!mounted) return;

      if (res != null) {
        final answer = res['answer']?.toString() ?? 'Thank you for your question. Reviewing the lesson materials.';
        _questionLimit = (res['questionLimit'] as num?)?.toInt() ?? _questionLimit;
        _questionsAsked = (res['questionsAsked'] as num?)?.toInt() ?? (_questionsAsked + 1);
        _questionsRemaining = (res['questionsRemaining'] as num?)?.toInt() ?? (_questionLimit - _questionsAsked);
        _isLimitReached = res['isLimitReached'] == true || _questionsRemaining <= 0;

        setState(() {
          _messages.add({'role': 'assistant', 'content': answer});
        });
      } else {
        setState(() {
          _error = 'Could not get an answer from the AI Tutor. Please try again.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error connecting to AI service: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _scrollToBottom();
      }
    }
  }

  Future<void> _clearChat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Chat History?', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
        content: const Text(
          'This will clear the conversation messages for this lesson.',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _api.clearLessonAiChat(widget.lesson.id);
      if (mounted) {
        setState(() {
          _messages.clear();
        });
      }
    }
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  void _scrollToTop({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    if (animated) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomInset = mq.viewInsets.bottom;
    final sheetHeight = _isExpanded ? (mq.size.height * 0.96) : (mq.size.height * 0.88);

    return Container(
      width: double.infinity,
      height: sheetHeight,
      decoration: const BoxDecoration(
        color: _bgNavy,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            spreadRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          _buildDragHandle(),
          _buildHeader(),
          if (_error != null) _buildErrorBanner(),
          if (_isLimitReached) _buildLimitReachedBanner(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _cyan))
                : _buildChatList(),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildDragHandle() {
    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: Container(
        width: 42,
        height: 4.5,
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.25),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    Color badgeColor;
    if (_questionsRemaining > 30) {
      badgeColor = const Color(0xFF10B981); // Green
    } else if (_questionsRemaining > 10) {
      badgeColor = const Color(0xFFF59E0B); // Amber
    } else {
      badgeColor = const Color(0xFFEF4444); // Red
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Row(
        children: [
          // AI Sparkle Avatar
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_cyan, _indigo],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _cyan.withOpacity(0.35),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 17),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    const Text(
                      'AI Tutor',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: _cyan.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _cyan.withOpacity(0.4), width: 0.8),
                      ),
                      child: const Text(
                        'PDF Context',
                        style: TextStyle(
                          color: _cyan,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  widget.lesson.heading.isNotEmpty ? widget.lesson.heading : widget.lesson.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Questions limit badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: badgeColor.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt, size: 11, color: badgeColor),
                const SizedBox(width: 2),
                Text(
                  '$_questionsRemaining/$_questionLimit left',
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 2),
          // Clear history button
          if (_messages.isNotEmpty)
            IconButton(
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(5),
              icon: Icon(Icons.delete_sweep_outlined, color: Colors.white.withOpacity(0.6), size: 18),
              onPressed: _clearChat,
              splashRadius: 16,
              tooltip: 'Clear chat',
            ),
          // Expand / collapse button
          IconButton(
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(5),
            icon: Icon(
              _isExpanded ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
              color: Colors.white.withOpacity(0.7),
              size: 20,
            ),
            onPressed: () => setState(() => _isExpanded = !_isExpanded),
            splashRadius: 16,
            tooltip: _isExpanded ? 'Restore size' : 'Expand full screen',
          ),
          // Close button
          IconButton(
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(5),
            icon: Icon(Icons.close_rounded, color: Colors.white.withOpacity(0.8), size: 20),
            onPressed: () => Navigator.pop(context),
            splashRadius: 16,
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      color: Colors.redAccent.withOpacity(0.15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitReachedBanner() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF59E0B).withOpacity(0.15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.lock_clock, color: Color(0xFFF59E0B), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'You have reached your limit of $_questionLimit questions for this lesson.',
              style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    if (_messages.isEmpty) {
      return _buildEmptyGreeting();
    }

    return ScrollConfiguration(
      behavior: const _AiChatScrollBehavior(),
      child: Stack(
        children: [
          Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            interactive: true,
            radius: const Radius.circular(8),
            thickness: 6,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragUpdate: (details) {
                if (_scrollController.hasClients) {
                  final delta = details.primaryDelta ?? 0.0;
                  final newOffset = (_scrollController.offset - delta).clamp(
                    0.0,
                    _scrollController.position.maxScrollExtent,
                  );
                  _scrollController.jumpTo(newOffset);
                }
              },
              onVerticalDragEnd: (details) {
                if (!_scrollController.hasClients) return;
                final velocity = details.primaryVelocity ?? 0.0;
                if (velocity.abs() > 80) {
                  final flingDistance = -velocity * 0.28;
                  final target = (_scrollController.offset + flingDistance).clamp(
                    0.0,
                    _scrollController.position.maxScrollExtent,
                  );
                  _scrollController.animateTo(
                    target,
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.decelerate,
                  );
                }
              },
              child: ListView.builder(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 30),
                itemCount: _messages.length + (_sending ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length && _sending) {
                    return _buildThinkingBubble();
                  }
                  final msg = _messages[index];
                  final isUser = msg['role'] == 'user';
                  return _buildMessageItem(msg['content'] ?? '', isUser);
                },
              ),
            ),
          ),
          // Quick Jump to Bottom floating button
          if (_showScrollToBottom)
            Positioned(
              right: 16,
              bottom: 12,
              child: Material(
                color: _indigo,
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _scrollToBottom(animated: true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_downward_rounded, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Latest',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // Quick Jump to Top floating button
          if (_showScrollToTop && !_showScrollToBottom)
            Positioned(
              right: 16,
              top: 10,
              child: Material(
                color: _cardNavy.withOpacity(0.9),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: _borderNavy.withOpacity(0.6)),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _scrollToTop(animated: true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_upward_rounded, color: _cyan, size: 13),
                        SizedBox(width: 3),
                        Text(
                          'Top',
                          style: TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyGreeting() {
    final title = widget.lesson.heading.isNotEmpty ? widget.lesson.heading : widget.lesson.title;
    return ScrollConfiguration(
      behavior: const _AiChatScrollBehavior(),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragUpdate: (details) {
          if (_scrollController.hasClients) {
            final delta = details.primaryDelta ?? 0.0;
            final newOffset = (_scrollController.offset - delta).clamp(
              0.0,
              _scrollController.position.maxScrollExtent,
            );
            _scrollController.jumpTo(newOffset);
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _cardNavy.withOpacity(0.85),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _borderNavy.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.waving_hand_rounded, color: Color(0xFFF59E0B), size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Welcome to AI Tutor!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'I am your AI study mentor for "$title". Ask me anything from the lesson notes or concepts. I can create comparison tables, explain formulas, write code examples, and solve doubts step by step.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'SUGGESTED QUESTIONS',
              style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _starterSuggestions.map((prompt) {
                return ActionChip(
                  backgroundColor: _cardNavy,
                  side: BorderSide(color: _cyan.withOpacity(0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  label: Text(
                    prompt,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onPressed: _isLimitReached ? null : () => _sendMessage(prompt),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildMessageItem(String content, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: BoxConstraints(
          maxWidth: isUser ? (MediaQuery.of(context).size.width * 0.82) : double.infinity,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isUser ? 14 : 12,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: isUser ? _indigo.withOpacity(0.88) : _cardNavy,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
          ),
          border: Border.all(
            color: isUser ? _indigo.withOpacity(0.6) : _borderNavy.withOpacity(0.8),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.16),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome, color: _cyan, size: 14),
                  const SizedBox(width: 5),
                  const Text(
                    'AI Tutor',
                    style: TextStyle(
                      color: _cyan,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: content));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Response copied to clipboard'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.copy_rounded, color: Colors.white.withOpacity(0.6), size: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            _buildFormattedText(content, isUser),
          ],
        ),
      ),
    );
  }

  Widget _buildThinkingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _cardNavy,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borderNavy.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: _cyan),
            ),
            const SizedBox(width: 10),
            Text(
              'Consulting lesson PDF & thinking...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.75),
                fontSize: 12.5,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Formats markdown content with support for GFM Tables, Headers, Code Blocks, and Lists.
  Widget _buildFormattedText(String text, bool isUser) {
    if (isUser) {
      return Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          height: 1.45,
        ),
      );
    }

    final normalized = _normalizeMarkdown(text);

    return Theme(
      data: Theme.of(context).copyWith(
        cardColor: const Color(0xFF0C2B64),
      ),
      child: MarkdownBody(
        data: normalized,
        selectable: false,
        onTapLink: (text, href, title) {
          if (href != null && href.isNotEmpty) {
            launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
          }
        },
        styleSheet: MarkdownStyleSheet(
          p: const TextStyle(
            color: Colors.white,
            fontSize: 13.5,
            height: 1.55,
          ),
          h1: const TextStyle(
            color: _cyan,
            fontSize: 17,
            fontWeight: FontWeight.bold,
            height: 1.35,
          ),
          h2: const TextStyle(
            color: _cyan,
            fontSize: 15.5,
            fontWeight: FontWeight.bold,
            height: 1.35,
          ),
          h3: const TextStyle(
            color: _cyan,
            fontSize: 14.5,
            fontWeight: FontWeight.bold,
            height: 1.35,
          ),
          h4: const TextStyle(
            color: Colors.white,
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
          ),
          strong: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          em: TextStyle(
            color: Colors.white.withOpacity(0.85),
            fontStyle: FontStyle.italic,
          ),
          listBullet: const TextStyle(
            color: _cyan,
            fontWeight: FontWeight.bold,
          ),
          blockquote: TextStyle(
            color: Colors.white.withOpacity(0.85),
            fontSize: 13,
            fontStyle: FontStyle.italic,
          ),
          blockquoteDecoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            border: const Border(left: BorderSide(color: _cyan, width: 3)),
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
          ),
          code: const TextStyle(
            color: _cyan,
            fontSize: 12,
            fontFamily: 'monospace',
            backgroundColor: Color(0xFF030712),
          ),
          codeblockDecoration: BoxDecoration(
            color: const Color(0xFF030712),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          codeblockPadding: const EdgeInsets.all(12),
          horizontalRuleDecoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.18), width: 1),
            ),
          ),
          // Tables styling
          tableHead: const TextStyle(
            color: _cyan,
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
          ),
          tableBody: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            height: 1.4,
          ),
          tableBorder: TableBorder.all(
            color: _borderNavy.withOpacity(0.8),
            width: 1,
            borderRadius: BorderRadius.circular(8),
          ),
          tableCellsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          tableHeadAlign: TextAlign.left,
          tableVerticalAlignment: TableCellVerticalAlignment.middle,
        ),
      ),
    );
  }

  /// Normalizes incoming AI markdown so tables and dividers format cleanly:
  /// 1. If an AI generates a table missing a delimiter row (| --- | --- |), synthesizes one.
  /// 2. Ensures horizontal rules (---) have double newlines so they don't convert prior text into H2 headers.
  String _normalizeMarkdown(String raw) {
    if (raw.isEmpty) return raw;

    final lines = raw.split('\n');
    final processed = <String>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      // Ensure horizontal rule --- has blank lines around it so markdown doesn't parse it as Setext header
      if (trimmed == '---' || trimmed == '***') {
        if (processed.isNotEmpty && processed.last.trim().isNotEmpty) {
          processed.add('');
        }
        processed.add('---');
        processed.add('');
        continue;
      }

      // Check for table lines starting and ending with pipe |
      if (trimmed.startsWith('|') && trimmed.endsWith('|')) {
        processed.add(trimmed);

        // Check if next line is already a delimiter (| --- | or |:--|)
        final nextLine = (i + 1 < lines.length) ? lines[i + 1].trim() : '';
        final isNextDelimiter = nextLine.startsWith('|') &&
            (nextLine.contains('---') || nextLine.contains(':--') || nextLine.contains('--:'));

        // If this is the first row of a table and next line is NOT a delimiter, synthesize one
        final isPreviousTableRow = (i > 0) && lines[i - 1].trim().startsWith('|');
        if (!isPreviousTableRow && !isNextDelimiter && nextLine.startsWith('|')) {
          final columnCount = trimmed.split('|').length - 2;
          if (columnCount > 0) {
            final delimiterRow = '| ${List.filled(columnCount, ':---').join(' | ')} |';
            processed.add(delimiterRow);
          }
        }
        continue;
      }

      processed.add(line);
    }

    return processed.join('\n');
  }

  Widget _buildInputBar() {
    final disabled = _sending || _isLimitReached;

    return SafeArea(
      top: false,
      bottom: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
        decoration: BoxDecoration(
          color: _bgNavy,
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: _cardNavy,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _focusNode.hasFocus ? _cyan : _borderNavy.withOpacity(0.4),
                    width: 1.2,
                  ),
                ),
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  enabled: !disabled,
                  textCapitalization: TextCapitalization.sentences,
                  cursorColor: _cyan,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: _cardNavy,
                    isDense: true,
                    hintText: _isLimitReached
                        ? 'Question limit reached for this lesson'
                        : 'Ask anything about this lesson...',
                    hintStyle: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13.5,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onSubmitted: disabled ? null : (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                gradient: disabled
                    ? LinearGradient(colors: [Colors.grey.shade700, Colors.grey.shade800])
                    : const LinearGradient(colors: [_cyan, _indigo]),
                shape: BoxShape.circle,
                boxShadow: disabled
                    ? null
                    : [
                        BoxShadow(
                          color: _cyan.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: disabled ? null : () => _sendMessage(),
                  child: const Padding(
                    padding: EdgeInsets.all(11),
                    child: Icon(
                      Icons.arrow_upward_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom scroll behavior enabling smooth touch, mouse, trackpad, and stylus dragging across all browsers & OS.
class _AiChatScrollBehavior extends MaterialScrollBehavior {
  const _AiChatScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}
