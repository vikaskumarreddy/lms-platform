import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    _loadHistory();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomInset = mq.viewInsets.bottom;
    final maxHeight = mq.size.height * 0.88;

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxHeight: maxHeight),
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
        mainAxisSize: MainAxisSize.min,
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
    return Container(
      width: 42,
      height: 4.5,
      margin: const EdgeInsets.only(top: 10, bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.25),
        borderRadius: BorderRadius.circular(3),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Row(
        children: [
          // AI Sparkle Avatar
          Container(
            width: 36,
            height: 36,
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
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
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
                        fontSize: 15,
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
                const SizedBox(height: 2),
                Text(
                  widget.lesson.heading.isNotEmpty ? widget.lesson.heading : widget.lesson.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Questions limit badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: badgeColor.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt, size: 12, color: badgeColor),
                const SizedBox(width: 2),
                Text(
                  '$_questionsRemaining/$_questionLimit left',
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(6),
            icon: Icon(Icons.close_rounded, color: Colors.white.withOpacity(0.8), size: 20),
            onPressed: () => Navigator.pop(context),
            splashRadius: 18,
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
              'You have reached your limit of $_questionLimit questions for this lesson. Customizable in Admin Portal.',
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

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: _messages.length + (_sending ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length && _sending) {
          return _buildThinkingBubble();
        }
        final msg = _messages[index];
        final isUser = msg['role'] == 'user';
        return _buildMessageItem(msg['content'] ?? '', isUser);
      },
    );
  }

  Widget _buildEmptyGreeting() {
    final title = widget.lesson.heading.isNotEmpty ? widget.lesson.heading : widget.lesson.title;
    return SingleChildScrollView(
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
                Row(
                  children: [
                    const Icon(Icons.waving_hand_rounded, color: Color(0xFFF59E0B), size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
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
                  'I am your AI study mentor for "$title". I use the lesson notes and PDF materials as my foundation, and can explain concepts, write code examples, and answer your doubts step by step.',
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
    );
  }

  Widget _buildMessageItem(String content, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? _indigo.withOpacity(0.85) : _cardNavy,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
          ),
          border: Border.all(
            color: isUser ? _indigo.withOpacity(0.5) : _borderNavy.withOpacity(0.6),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 4,
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
                  const SizedBox(width: 4),
                  const Text(
                    'AI Tutor',
                    style: TextStyle(
                      color: _cyan,
                      fontSize: 11,
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
                      padding: const EdgeInsets.all(2),
                      child: Icon(Icons.copy_rounded, color: Colors.white.withOpacity(0.5), size: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
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
          border: Border.all(color: _borderNavy.withOpacity(0.4)),
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

  Widget _buildFormattedText(String text, bool isUser) {
    if (text.contains('```')) {
      final parts = text.split('```');
      final widgets = <Widget>[];

      for (int i = 0; i < parts.length; i++) {
        final part = parts[i];
        if (i % 2 == 1) {
          // Code block
          String code = part;
          String? lang;
          final firstLineBreak = part.indexOf('\n');
          if (firstLineBreak != -1) {
            lang = part.substring(0, firstLineBreak).trim();
            code = part.substring(firstLineBreak + 1);
          }
          widgets.add(_buildCodeBlock(code, lang));
        } else if (part.trim().isNotEmpty) {
          widgets.add(_buildMarkdownParagraph(part, isUser));
        }
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widgets,
      );
    }

    return _buildMarkdownParagraph(text, isUser);
  }

  Widget _buildMarkdownParagraph(String text, bool isUser) {
    final lines = text.split('\n');
    final widgets = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 5));
        continue;
      }

      // Headers like ### Header or ## Header or # Header
      if (trimmed.startsWith(RegExp(r'^#{1,6}\s+'))) {
        final title = trimmed.replaceFirst(RegExp(r'^#{1,6}\s+'), '');
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              title,
              style: const TextStyle(
                color: _cyan,
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
              ),
            ),
          ),
        );
        continue;
      }

      // Regular line with inline markdown formatting: **bold**, *italic*, `code`
      final spans = _parseInlineMarkdown(line);
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 1.5),
          child: Text.rich(
            TextSpan(children: spans),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  List<InlineSpan> _parseInlineMarkdown(String line) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'(\*\*[^*]+?\*\*|\*[^*]+?\*|`[^`]+?`)');
    int lastIndex = 0;

    for (final match in pattern.allMatches(line)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: line.substring(lastIndex, match.start)));
      }

      final matchedText = match.group(0)!;
      if (matchedText.startsWith('**') && matchedText.endsWith('**')) {
        spans.add(
          TextSpan(
            text: matchedText.substring(2, matchedText.length - 2),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
      } else if (matchedText.startsWith('*') && matchedText.endsWith('*')) {
        spans.add(
          TextSpan(
            text: matchedText.substring(1, matchedText.length - 1),
            style: const TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.white70,
            ),
          ),
        );
      } else if (matchedText.startsWith('`') && matchedText.endsWith('`')) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF030712),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(
                matchedText.substring(1, matchedText.length - 1),
                style: const TextStyle(
                  color: _cyan,
                  fontSize: 11.5,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        );
      }

      lastIndex = match.end;
    }

    if (lastIndex < line.length) {
      spans.add(TextSpan(text: line.substring(lastIndex)));
    }

    return spans;
  }

  Widget _buildCodeBlock(String code, String? lang) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF030712),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (lang != null && lang.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: Row(
                children: [
                  Text(
                    lang.toUpperCase(),
                    style: TextStyle(
                      color: _cyan.withOpacity(0.9),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: code.trim()));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copied!'), duration: Duration(seconds: 1)),
                      );
                    },
                    child: const Icon(Icons.copy_rounded, color: Colors.white60, size: 12),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: SelectableText(
              code.trim(),
              style: const TextStyle(
                color: Color(0xFFE2E8F0),
                fontSize: 12,
                fontFamily: 'monospace',
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
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
