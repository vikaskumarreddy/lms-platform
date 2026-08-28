import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/common_header.dart';

class DiscussionScreen extends StatefulWidget {
  final int lessonId;
  const DiscussionScreen({super.key, required this.lessonId});

  @override
  State<DiscussionScreen> createState() => _DiscussionScreenState();
}

class _DiscussionScreenState extends State<DiscussionScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _commentController = TextEditingController();
  List<_CommentItem> _topLevelComments = [];
  bool _loading = true;
  bool _posting = false;
  int? _replyingToId;
  final TextEditingController _replyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _loading = true);
    final raw = await _api.getCommentsForLesson(widget.lessonId);
    if (!mounted) return;

    final byId = <int, _CommentItem>{};
    for (final entry in raw) {
      final item = _CommentItem(
        id: (entry['id'] as num).toInt(),
        author: (entry['authorName'] as String?) ?? 'Anonymous',
        text: (entry['content'] as String?) ?? '',
        time: (entry['createdAt'] as String?) ?? '',
        parentId: (entry['parentId'] as num?)?.toInt(),
      );
      byId[item.id] = item;
    }

    final topLevel = <_CommentItem>[];
    for (final item in byId.values) {
      if (item.parentId != null && byId.containsKey(item.parentId)) {
        byId[item.parentId]!.replies.add(item);
      } else {
        topLevel.add(item);
      }
    }

    setState(() {
      _topLevelComments = topLevel;
      _loading = false;
    });
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _posting) return;

    setState(() => _posting = true);
    final success = await _api.postComment(lessonId: widget.lessonId, content: text);
    if (!mounted) return;
    setState(() => _posting = false);

    if (success) {
      _commentController.clear();
      _loadComments();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to post comment. Please try again.')),
      );
    }
  }

  Future<void> _submitReply(int parentId) async {
    final text = _replyController.text.trim();
    if (text.isEmpty || _posting) return;

    setState(() => _posting = true);
    final success = await _api.postComment(lessonId: widget.lessonId, content: text, parentId: parentId);
    if (!mounted) return;
    setState(() {
      _posting = false;
      if (success) _replyingToId = null;
    });

    if (success) {
      _replyController.clear();
      _loadComments();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to post reply. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonHeader(title: 'Discussion - Lesson ${widget.lessonId}'),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.grey.shade50),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      prefixIcon: const Icon(Icons.comment, size: 20),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    onSubmitted: (_) => _submitComment(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _posting ? null : _submitComment,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _topLevelComments.isEmpty
                    ? Center(
                        child: Text(
                          'No comments yet. Start the discussion!',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadComments,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _topLevelComments.length,
                          itemBuilder: (context, index) => _buildCommentCard(_topLevelComments[index]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentCard(_CommentItem comment, {bool isReply = false}) {
    return Padding(
      padding: EdgeInsets.only(left: isReply ? 32 : 0, bottom: 12),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    child: Text(
                      comment.author.isNotEmpty ? comment.author[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(comment.author, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(comment.time, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(comment.text, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _replyingToId = _replyingToId == comment.id ? null : comment.id;
                    _replyController.clear();
                  });
                },
                icon: Icon(Icons.reply, size: 16, color: Colors.grey.shade600),
                label: Text('Reply', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
              ),
              if (_replyingToId == comment.id) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _replyController,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Write a reply...',
                          isDense: true,
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                        onSubmitted: (_) => _submitReply(comment.id),
                      ),
                    ),
                    IconButton(
                      onPressed: _posting ? null : () => _submitReply(comment.id),
                      icon: const Icon(Icons.send, size: 18),
                    ),
                  ],
                ),
              ],
              for (final reply in comment.replies) ...[
                const SizedBox(height: 12),
                _buildCommentCard(reply, isReply: true),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentItem {
  final int id;
  final String author;
  final String text;
  final String time;
  final int? parentId;
  final List<_CommentItem> replies;

  _CommentItem({
    required this.id,
    required this.author,
    required this.text,
    required this.time,
    this.parentId,
    List<_CommentItem>? replies,
  }) : replies = replies ?? [];
}
