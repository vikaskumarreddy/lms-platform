import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/common_header.dart';
import '../../../data/models/lesson.dart';
import '../../../core/services/api_service.dart';

class LessonPlayerScreen extends StatefulWidget {
  final int lessonId;
  const LessonPlayerScreen({super.key, required this.lessonId});

  @override
  State<LessonPlayerScreen> createState() => _LessonPlayerScreenState();
}

class _LessonPlayerScreenState extends State<LessonPlayerScreen> {
  final ApiService _api = ApiService();
  Lesson? _lesson;
  bool _loading = true;
  bool _isCompleted = false;
  bool _isBookmarked = false;
  bool _togglingComplete = false;
  bool _togglingBookmark = false;

  @override
  void initState() {
    super.initState();
    _loadLesson();
  }

  Future<void> _loadLesson() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _api.getLesson(widget.lessonId),
      _api.getLessonStatus(widget.lessonId),
    ]);
    setState(() {
      _lesson = results[0] as Lesson?;
      final status = results[1] as Map<String, dynamic>;
      _isCompleted = status['completed'] ?? false;
      _isBookmarked = status['bookmarked'] ?? false;
      _loading = false;
    });
  }

  Future<void> _toggleComplete() async {
    if (_togglingComplete) return;
    setState(() => _togglingComplete = true);
    final completed = await _api.toggleLessonComplete(widget.lessonId);
    setState(() {
      _isCompleted = completed;
      _togglingComplete = false;
    });
  }

  Future<void> _toggleBookmark() async {
    if (_togglingBookmark) return;
    setState(() => _togglingBookmark = true);
    final bookmarked = await _api.toggleLessonBookmark(widget.lessonId);
    setState(() {
      _isBookmarked = bookmarked;
      _togglingBookmark = false;
    });
  }

  void _downloadPdf() {
    final pdfUrl = _lesson?.pdfNotesUrl;
    if (pdfUrl == null || pdfUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No PDF notes available for this lesson')),
        );
      }
      return;
    }
    // Open PDF in embedded in-app browser (same as calendar events / placement drives)
    final title = _lesson?.title ?? 'PDF Notes';
    context.push('/browser?url=${Uri.encodeComponent(pdfUrl)}&title=${Uri.encodeComponent(title)}');
  }

  /// Builds an embeddable YouTube iframe URL from the video URL.
  String _youtubeEmbedUrl(String videoUrl) {
    final videoId = _extractYouTubeVideoId(videoUrl);
    return 'https://www.youtube.com/embed/$videoId?rel=0&modestbranding=1&playsinline=1';
  }

  /// Extracts the YouTube video ID from various URL formats.
  String _extractYouTubeVideoId(String videoUrl) {
    if (videoUrl.isEmpty) return '6XwD57dwZew';
    final uri = Uri.tryParse(videoUrl);
    if (uri == null) return '6XwD57dwZew';
    final watchId = uri.queryParameters['v'];
    if (watchId != null && watchId.isNotEmpty) return watchId;
    final pathSegments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (pathSegments.isNotEmpty) {
      final last = pathSegments.last;
      if (last.length == 11) return last;
    }
    return '6XwD57dwZew';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        appBar: CommonHeader(showBackButton: true, title: 'Lesson'),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final lesson = _lesson;
    if (lesson == null) {
      return Scaffold(
        appBar: const CommonHeader(showBackButton: true, title: 'Lesson'),
        body: const Center(child: Text('Lesson not found')),
      );
    }

    final primaryColor = const Color(0xFF0F172A);
    final secondaryColor = const Color(0xFFEAB308);

    return Scaffold(
      appBar: CommonHeader(showBackButton: true, title: lesson.title),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Video player (YouTube iframe embed) ──
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 220,
              color: Colors.black,
              child: lesson.isLocked
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock, color: Colors.grey.shade400, size: 48),
                          const SizedBox(height: 12),
                          Text('Upgrade to unlock', style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
                        ],
                      ),
                    )
                  : InAppWebView(
                      initialUrlRequest: URLRequest(
                        url: WebUri(_youtubeEmbedUrl(lesson.videoUrl)),
                      ),
                      initialSettings: InAppWebViewSettings(
                        javaScriptEnabled: true,
                        allowsInlineMediaPlayback: true,
                        mediaPlaybackRequiresUserGesture: false,
                        transparentBackground: true,
                      ),
                      onWebViewCreated: (controller) {},
                      onReceivedError: (controller, request, error) {},
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  lesson.heading,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: primaryColor),
                ),
              ),
              if (!lesson.isLocked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: secondaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule, size: 14, color: Color(0xFFEAB308)),
                      const SizedBox(width: 4),
                      Text(lesson.duration, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Lesson Notes ──
          if (lesson.isLocked)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock, color: Color(0xFFEAB308)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Notes are locked. Upgrade your subscription to access the study material for this lesson.',
                      style: TextStyle(color: Colors.grey.shade700, height: 1.5),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lesson Notes',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: primaryColor),
                  ),
                  const SizedBox(height: 16),
                  ..._buildNotes(lesson.notes, context),
                  const SizedBox(height: 12),
                  Text(
                    'This content is configurable from the admin panel.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),

          // ── Action buttons ──
          Row(
            children: [
              // Download PDF button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: lesson.isLocked ? null : _downloadPdf,
                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                  label: const Text('PDF Notes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade50,
                    foregroundColor: Colors.red.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Bookmark button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: lesson.isLocked ? null : _toggleBookmark,
                  icon: Icon(
                    _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    size: 18,
                  ),
                  label: Text(_isBookmarked ? 'Bookmarked' : 'Bookmark'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                    foregroundColor: primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Mark Complete button (full width)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (lesson.isLocked || _togglingComplete) ? null : _toggleComplete,
              icon: _togglingComplete
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _isCompleted ? Icons.check_circle : Icons.check_circle_outline,
                      size: 20,
                    ),
              label: Text(_isCompleted ? 'Completed' : 'Mark as Complete'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isCompleted ? Colors.green : secondaryColor,
                foregroundColor: _isCompleted ? Colors.white : Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildNotes(String notes, BuildContext context) {
    final primaryColor = const Color(0xFF0F172A);
    final text = _htmlToPlainText(notes);
    final paragraphs = text.split('\n\n').where((p) => p.trim().isNotEmpty).toList();

    return paragraphs.map((paragraph) {
      final lines = paragraph.split('\n').where((l) => l.trim().isNotEmpty).toList();
      final isBulletList = lines.every((l) => l.trimLeft().startsWith('-'));

      if (isBulletList) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12, left: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: lines.map((line) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 7),
                      child: Icon(Icons.circle, size: 6, color: Color(0xFFEAB308)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        line.trimLeft().substring(1).trim(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6, color: Colors.grey.shade800),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      }

      final heading = lines.first;
      final explanation = lines.sublist(1).join(' ');

      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (explanation.isNotEmpty)
              Text(
                heading,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 15),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAB308).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border(left: BorderSide(color: const Color(0xFFEAB308), width: 4)),
                ),
                child: Text(
                  heading,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: primaryColor),
                ),
              ),
            if (explanation.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                explanation,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.7, color: Colors.grey.shade700),
              ),
            ],
          ],
        ),
      );
    }).toList();
  }

  String _htmlToPlainText(String html) {
    if (html.isEmpty) return '';
    var text = html;
    text = text.replaceAll(RegExp(r'</?(h[1-6]|p|div|section|article|ul|ol|li|pre|blockquote)[^>]*>', caseSensitive: false), '\n\n');
    text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '\n- ');
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');
    const ampersand = '\u0026';
    text = text.replaceAll('$ampersand nbsp;', ' ')
        .replaceAll('$ampersand amp;', '*')
        .replaceAll('$ampersand lt;', '<')
        .replaceAll('$ampersand gt;', '>')
        .replaceAll('$ampersand quot;', '"')
        .replaceAll('$ampersand #39;', "'")
        .replaceAll('$ampersand apos;', "'");
    text = text.replaceAll('*', ampersand);
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }
}