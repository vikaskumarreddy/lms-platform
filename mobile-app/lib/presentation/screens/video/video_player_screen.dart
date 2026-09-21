import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/lesson_media.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/widgets/common_header.dart';
import '../../../data/models/lesson.dart';
import '../../../core/services/api_service.dart';

class LessonPlayerScreen extends ConsumerStatefulWidget {
  final int lessonId;
  const LessonPlayerScreen({super.key, required this.lessonId});

  @override
  ConsumerState<LessonPlayerScreen> createState() => _LessonPlayerScreenState();
}

class _LessonPlayerScreenState extends ConsumerState<LessonPlayerScreen> {
  final ApiService _api = ApiService();
  Lesson? _lesson;
  bool _loading = true;
  bool _isCompleted = false;
  bool _isBookmarked = false;
  bool _togglingComplete = false;
  bool _togglingBookmark = false;
  bool _videoLoadFailed = false;
  int _videoRetryKey = 0;
  String? _mediaToken;

  /// The open study-time session for this lesson. Recorded so the dashboard's
  /// "Time Spending" trend reflects real time in the player rather than nothing.
  int? _studyLogId;

  // ── Floating (YouTube-style PiP) video ──────────────────────────────────
  // The video is NOT pinned to the top of the page. Instead it renders as a
  // draggable popup overlaying the lesson: the PDF notes occupy the full page
  // and the video floats above them at the bottom-right, and can be dragged
  // anywhere, resized between compact/full-width, hidden, and restored.
  Offset? _videoOffset; // null until first layout (needs screen size)
  bool _videoHidden = false;
  bool _videoExpanded = false;
  // Keeps the WebView's Element alive while the Positioned wrapper around it
  // changes (drag/resize) so playback is never interrupted.
  final GlobalKey _videoKey = GlobalKey();

  // ── PDF notes (rendered inline, native, no separate screen) ───
  String? _pdfLocalPath;
  String? _pdfError;
  bool _pdfLoading = false;
  bool _pdfSaving = false;
  PDFViewController? _pdfViewController;
  int _pdfCurrentPage = 0;
  int _pdfTotalPages = 0;

  @override
  void initState() {
    super.initState();
    _loadLesson();
    _startStudySession();
  }

  /// Opens a study-time session for this lesson.
  ///
  /// Deliberately not awaited in a setState: the player must render immediately,
  /// and a failed call simply means no time is recorded for this visit.
  Future<void> _startStudySession() async {
    final logId = await _api.startStudySession(lessonId: widget.lessonId);
    if (!mounted) {
      // Screen already gone (quick back-out) — close whatever the server opened.
      if (logId != null) await _api.endStudySession(logId: logId);
      return;
    }
    _studyLogId = logId;
  }

  @override
  void dispose() {
    // Closes the session opened on entry. Even if this call never lands (the OS
    // can kill the process first), the backend caps the session and closes any
    // still-open row on the student's next visit, so time can't run on forever.
    _api.endStudySession(logId: _studyLogId);
    super.dispose();
  }

  Future<void> _loadLesson() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    _mediaToken = prefs.getString('access_token');
    final results = await Future.wait([
      _api.getLesson(widget.lessonId),
      _api.getLessonStatus(widget.lessonId),
    ]);
    if (!mounted) return;
    setState(() {
      _lesson = results[0] as Lesson?;
      final status = results[1] as Map<String, dynamic>;
      _isCompleted = status['completed'] ?? false;
      _isBookmarked = status['bookmarked'] ?? false;
      _loading = false;
    });
    final pdfUrl = _lesson?.pdfNotesUrl;
    if (!(_lesson?.isLocked ?? true) && pdfUrl != null && pdfUrl.isNotEmpty) {
      _loadPdfInline();
    }
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

  /// Downloads the lesson's PDF notes and renders them natively, in place,
  /// right where the old free-text "Lesson Notes" section used to be — no
  /// separate screen, no WebView, no external viewer. The PDF's own layout
  /// (headings, bullets, images, exact formatting) is preserved perfectly
  /// since students see the real document instead of a lossy HTML rewrite of
  /// pasted notes.
  Future<void> _loadPdfInline() async {
    final pdfUrl = _lesson?.pdfNotesUrl;
    if (pdfUrl == null || pdfUrl.isEmpty) return;
    setState(() {
      _pdfLoading = true;
      _pdfError = null;
      _pdfLocalPath = null;
    });
    try {
      final url = _absoluteMediaUrl(pdfUrl);
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        setState(() => _pdfError = 'Could not load the notes for this lesson.');
        return;
      }
      final bytes = response.bodyBytes;
      if (bytes.isEmpty) {
        setState(() => _pdfError = 'Notes for this lesson are empty.');
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/lesson_notes_${widget.lessonId}.pdf');
      await file.writeAsBytes(bytes, flush: true);
      if (mounted) setState(() => _pdfLocalPath = file.path);
    } catch (_) {
      if (mounted)
        setState(() => _pdfError =
            'Could not load the notes. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _pdfLoading = false);
    }
  }

  /// Saves the lesson's PDF to the device via the OS share sheet (Save to
  /// Files / Downloads / Drive, etc.) — no storage-permission dance, works
  /// identically on Android and iOS.
  Future<void> _downloadPdf() async {
    if (_pdfSaving) return;
    final pdfUrl = _lesson?.pdfNotesUrl;
    if (pdfUrl == null || pdfUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No PDF notes available for this lesson')),
        );
      }
      return;
    }
    setState(() => _pdfSaving = true);
    try {
      String? path = _pdfLocalPath;
      if (path == null) {
        final url = _absoluteMediaUrl(pdfUrl);
        final response =
            await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
        if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
          throw Exception('download failed');
        }
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/lesson_notes_${widget.lessonId}.pdf');
        await file.writeAsBytes(response.bodyBytes, flush: true);
        path = file.path;
      }
      final safeName = (_lesson?.title ?? 'Lesson Notes')
          .replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '')
          .trim();
      await Share.shareXFiles(
        [
          XFile(path,
              name: '${safeName.isEmpty ? 'lesson_notes' : safeName}.pdf')
        ],
        text: _lesson?.title ?? 'Lesson Notes',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Could not download this PDF. Check your connection and try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _pdfSaving = false);
    }
  }

  String _absoluteMediaUrl(String url) =>
      lessonMediaUrl(url, ApiService.baseUrl, token: _mediaToken);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const CommonHeaderScaffold(
        subtitle: 'Lesson',
        showBackButton: true,
        backgroundColor: Color(0xFF071D43),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF27D9D3)),
        ),
      );
    }

    final lesson = _lesson;
    if (lesson == null) {
      return const CommonHeaderScaffold(
        subtitle: 'Lesson',
        showBackButton: true,
        backgroundColor: Color(0xFF071D43),
        body: Center(
          child: Text('Lesson not found',
              style: TextStyle(color: Colors.white70, fontSize: 16)),
        ),
      );
    }

    final primaryColor = Theme.of(context).colorScheme.primary;
    final secondaryColor = Theme.of(context).colorScheme.secondary;
    final isNavBarHidden = ref.watch(shellNavBarHiddenProvider);

    final hasVideo = lesson.videoUrl.trim().isNotEmpty;

    if (lesson.isLocked) {
      return _buildLockedLessonBody(lesson, primaryColor, secondaryColor, isNavBarHidden);
    }

    return CommonHeaderScaffold(
      subtitle: 'Lesson',
      showBackButton: true,
      backgroundColor: const Color(0xFF071D43),
      body: Stack(
        children: [
          // ── Base layer: heading, duration, PDF notes, and action buttons ──
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        lesson.heading,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF27D9D3).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFF27D9D3).withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.schedule,
                              size: 14, color: Color(0xFF27D9D3)),
                          const SizedBox(width: 4),
                          Text(
                            lesson.duration,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildPdfNotesSection(primaryColor, fill: true, isNavBarHidden: isNavBarHidden),
                ),
              ),
              _buildActionButtons(lesson, primaryColor, secondaryColor, isNavBarHidden: isNavBarHidden),
            ],
          ),
          // ── Floating draggable video (YouTube-style picture-in-picture) ──
          if (hasVideo && !_videoHidden) _buildFloatingVideo(lesson, isNavBarHidden),
          if (hasVideo && _videoHidden) _buildRestoreVideoChip(isNavBarHidden),
        ],
      ),
    );
  }

  /// Locked lessons keep the classic stacked layout — the video frame (locked)
  /// followed by the locked-notes notice and the action buttons.
  Widget _buildLockedLessonBody(
      Lesson lesson, Color primaryColor, Color secondaryColor, bool isNavBarHidden) {
    return CommonHeaderScaffold(
      subtitle: 'Lesson',
      showBackButton: true,
      backgroundColor: const Color(0xFF071D43),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, isNavBarHidden ? 24 : 96),
        children: [
          // ── Video player (locked for this subscription tier) ──
          if (lesson.videoUrl.trim().isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 220,
                decoration: BoxDecoration(
                  color: const Color(0xFF0C2B64).withOpacity(0.7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: const Color(0xFF1E4E8C).withOpacity(0.5)),
                ),
                child: lesson.isLocked
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock,
                                color: Color(0xFFFFCF35), size: 48),
                            SizedBox(height: 12),
                            Text('Upgrade to unlock',
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )
                    : _videoLoadFailed
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline,
                                    color: Colors.white54, size: 48),
                                const SizedBox(height: 12),
                                const Text('Video failed to load',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 16)),
                                const SizedBox(height: 12),
                                TextButton.icon(
                                  onPressed: () => setState(() {
                                    _videoLoadFailed = false;
                                    _videoRetryKey++;
                                  }),
                                  icon: const Icon(Icons.refresh,
                                      color: Color(0xFF27D9D3)),
                                  label: const Text('Retry',
                                      style:
                                          TextStyle(color: Color(0xFF27D9D3))),
                                ),
                              ],
                            ),
                          )
                        : _buildVideoPlayer(lesson),
              ),
            ),
          if (lesson.videoUrl.trim().isNotEmpty) const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  lesson.heading,
                  style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
              if (!lesson.isLocked)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF27D9D3).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFF27D9D3).withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule,
                          size: 14, color: Color(0xFF27D9D3)),
                      const SizedBox(width: 4),
                      Text(lesson.duration,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Lesson Notes (locked notice) ──
          if (lesson.isLocked)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0C2B64).withOpacity(0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFF1E4E8C).withOpacity(0.5)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock, color: Color(0xFFFFCF35)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Notes are locked. Upgrade your subscription to access the study material for this lesson.',
                      style: TextStyle(color: Colors.white70, height: 1.5),
                    ),
                  ),
                ],
              ),
            )
          else
            _buildPdfNotesSection(primaryColor, isNavBarHidden: isNavBarHidden),
          const SizedBox(height: 20),

          // ── Action buttons ──
          _buildActionButtons(lesson, primaryColor, secondaryColor,
              isNavBarHidden: isNavBarHidden),
        ],
      ),
    );
  }

  /// Renders the lesson's PDF inline, right where free-text "Lesson Notes"
  /// used to appear — real native PDF pages instead of an HTML rewrite, so
  /// the original document's structure/formatting is preserved exactly.
  ///
  /// When [fill] is true (floating-video layout) the PDF stretches to fill
  /// all remaining vertical space instead of using a fixed 520px window.
  /// When [isNavBarHidden] is true, the fixed window expands dynamically so the student
  /// has a large distraction-free viewing area.
  Widget _buildPdfNotesSection(Color primaryColor,
      {bool fill = false, required bool isNavBarHidden}) {
    final hasPdf = (_lesson?.pdfNotesUrl ?? '').isNotEmpty;
    if (!hasPdf) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0C2B64).withOpacity(0.65),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1E4E8C).withOpacity(0.5)),
        ),
        child: const Row(
          children: [
            Icon(Icons.description_outlined, color: Colors.white38),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'No notes have been added for this lesson yet.',
                style: TextStyle(color: Colors.white60, height: 1.5),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0C2B64).withOpacity(0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E4E8C).withOpacity(0.5)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Lesson Notes',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white),
              ),
              const Spacer(),
              if (_pdfLoading)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF27D9D3))),
                ),
              if (_pdfLocalPath != null && _pdfError == null)
                IconButton(
                  onPressed: _openFullscreenPdf,
                  icon: const Icon(Icons.fullscreen, color: Colors.white),
                  tooltip: 'Expand',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_pdfError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  const Icon(Icons.error_outline,
                      size: 40, color: Colors.white54),
                  const SizedBox(height: 12),
                  Text(_pdfError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _loadPdfInline,
                    icon: const Icon(Icons.refresh, color: Color(0xFF27D9D3)),
                    label: const Text('Retry',
                        style: TextStyle(color: Color(0xFF27D9D3))),
                  ),
                ],
              ),
            )
          else if (_pdfLocalPath == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF27D9D3))),
            )
          else ...[
            if (fill)
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _buildPdfView(_pdfLocalPath!),
                ),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  height: isNavBarHidden
                      ? (MediaQuery.of(context).size.height * 0.75)
                          .clamp(650.0, 950.0)
                      : 520.0,
                  child: _buildPdfView(_pdfLocalPath!),
                ),
              ),
            if (_pdfTotalPages > 0) ...[
              const SizedBox(height: 8),
              _buildPdfPageControls(primaryColor),
            ],
          ],
        ],
      ),
    );
  }

  /// Download / Bookmark / Mark-complete buttons — shared by the locked
  /// (stacked) layout and the unlocked (floating-video) layout.
  Widget _buildActionButtons(
      Lesson lesson, Color primaryColor, Color secondaryColor,
      {required bool isNavBarHidden}) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      padding: EdgeInsets.fromLTRB(16, 12, 16, isNavBarHidden ? 16 : 96),
      child: Column(
        children: [
          Row(
            children: [
              // Download PDF button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (lesson.isLocked ||
                          _pdfSaving ||
                          (lesson.pdfNotesUrl.isEmpty))
                      ? null
                      : _downloadPdf,
                  icon: _pdfSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.download, size: 18),
                  label: Text(_pdfSaving ? 'Saving...' : 'Download PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444).withOpacity(0.18),
                    foregroundColor: const Color(0xFFF87171),
                    side: BorderSide(
                        color: const Color(0xFFEF4444).withOpacity(0.4)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
                    color: _isBookmarked ? const Color(0xFFF59E0B) : Colors.white,
                  ),
                  label: Text(_isBookmarked ? 'Bookmarked' : 'Bookmark'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0C2B64).withOpacity(0.8),
                    foregroundColor: Colors.white,
                    side: BorderSide(
                        color: const Color(0xFF1E4E8C).withOpacity(0.6)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Mark Complete button (full width)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (lesson.isLocked || _togglingComplete)
                  ? null
                  : _toggleComplete,
              icon: _togglingComplete
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(
                      _isCompleted
                          ? Icons.check_circle
                          : Icons.check_circle_outline,
                      size: 20,
                    ),
              label: Text(_isCompleted ? 'Completed' : 'Mark as Complete'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isCompleted
                    ? const Color(0xFF10B981)
                    : const Color(0xFF27D9D3),
                foregroundColor:
                    _isCompleted ? Colors.white : const Color(0xFF071D43),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// YouTube-style draggable video popup. Floats above the full-page PDF at
  /// the bottom-right by default, can be dragged anywhere, resized between
  /// compact and full-width (double-tap or the expand button), and closed —
  /// after which a restore chip brings it back. The [KeyedSubtree] with
  /// [_videoKey] keeps the WebView Element alive across drags/resizes so
  /// playback is never interrupted.
  Widget _buildFloatingVideo(Lesson lesson, bool isNavBarHidden) {
    final size = MediaQuery.of(context).size;
    final double w = _videoExpanded ? size.width - 24 : 224.0;
    final double h = _videoExpanded ? w * 9 / 16 : 132.0;
    // Default position: lower half of the screen (above the action buttons).
    _videoOffset ??= Offset(size.width - w - 16, size.height * 0.45);
    final double dx = _videoOffset!.dx
        .clamp(0.0, (size.width - w).clamp(0.0, double.infinity));
    final double bottomInset = isNavBarHidden ? 30.0 : 110.0;
    final double dy = _videoOffset!.dy
        .clamp(0.0, (size.height - h - bottomInset).clamp(0.0, double.infinity));
    return Positioned(
      left: dx,
      top: dy,
      width: w,
      height: h,
      child: GestureDetector(
        // Dragging the popup repositions it; taps still pass through to the
        // WebView so the video's own play/pause controls keep working.
        onPanUpdate: (details) {
          setState(() {
            _videoOffset = Offset(dx + details.delta.dx, dy + details.delta.dy);
          });
        },
        onDoubleTap: () => setState(() => _videoExpanded = !_videoExpanded),
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          color: Colors.black,
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: KeyedSubtree(
                  key: _videoKey,
                  child: _buildVideoPlayer(lesson),
                ),
              ),
              // Popup controls (expand + close)
              Positioned(
                top: 4,
                right: 4,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _pipButton(
                      _videoExpanded ? Icons.compress : Icons.open_in_full,
                      tooltip: _videoExpanded ? 'Shrink' : 'Enlarge',
                      onTap: () =>
                          setState(() => _videoExpanded = !_videoExpanded),
                    ),
                    const SizedBox(width: 4),
                    _pipButton(
                      Icons.close,
                      tooltip: 'Hide video',
                      onTap: () => setState(() => _videoHidden = true),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Small round translucent button used on the floating video popup.
  Widget _pipButton(IconData icon,
      {required String tooltip, required VoidCallback onTap}) {
    return Material(
      color: Colors.black.withOpacity(0.55),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(icon, size: 16, color: Colors.white),
          ),
        ),
      ),
    );
  }

  /// Shown after the popup is closed — restores the floating video.
  Widget _buildRestoreVideoChip(bool isNavBarHidden) {
    return Positioned(
      right: 16,
      bottom: isNavBarHidden ? 76 : 110,
      child: FloatingActionButton(
        heroTag: 'restoreLessonVideo',
        tooltip: 'Show video',
        backgroundColor: const Color(0xFF27D9D3),
        foregroundColor: const Color(0xFF071D43),
        onPressed: () => setState(() {
          _videoHidden = false;
          _videoOffset = null; // snap back to the default position
        }),
        child: const Icon(Icons.play_circle_fill, size: 28),
      ),
    );
  }

  /// The actual video renderer (retry-on-error, self-hosted HTML5 video,
  /// or YouTube embed). Shared by the floating popup and the locked layout.
  Widget _buildVideoPlayer(Lesson lesson) {
    if (_videoLoadFailed) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.grey.shade400, size: 36),
            const SizedBox(height: 8),
            Text('Video failed to load',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => setState(() {
                _videoLoadFailed = false;
                _videoRetryKey++;
              }),
              icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
              label: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
    final video = resolveLessonVideoSource(lesson, ApiService.baseUrl,
        token: _mediaToken);
    final youtube = video.youtube;
    final origin = video.origin;
    final url = video.url;
    return InAppWebView(
      key: ValueKey('video_$_videoRetryKey'),
      initialData: InAppWebViewInitialData(
        data: videoDocument(url, youtube: youtube),
        baseUrl: WebUri('$origin/'),
        mimeType: 'text/html',
        encoding: 'utf-8',
      ),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        allowsInlineMediaPlayback: true,
        mediaPlaybackRequiresUserGesture: false,
        useHybridComposition: true,
        // Non-browser agent prevents ngrok warning HTML on media range requests.
        userAgent: youtube ? null : 'LMSStudentMedia/1.0',
      ),
      onWebViewCreated: (controller) {
        controller.addJavaScriptHandler(
            handlerName: 'videoError',
            callback: (args) {
              if (mounted) setState(() => _videoLoadFailed = true);
            });
      },
      onReceivedError: (controller, request, error) {
        if (mounted && request.isForMainFrame == true) {
          setState(() => _videoLoadFailed = true);
        }
      },
    );
  }

  /// A plain PDFView wired to keep [_pdfCurrentPage]/[_pdfTotalPages] in sync
  /// so the page-navigation controls below it work.
  ///
  /// [gestureRecognizers] is the crucial bit: the inline PDF sits inside the
  /// lesson screen's outer [ListView], which otherwise captures vertical drags
  /// and the PDF can never scroll/zoom on its own. Claiming the gestures here
  /// hands them to the native renderer so in-page scrolling + pinch-to-zoom
  /// work as expected.
  Widget _buildPdfView(String path) {
    return PDFView(
      filePath: path,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: true,
      pageFling: true,
      pageSnap: false,
      fitPolicy: FitPolicy.WIDTH,
      gestureRecognizers: {
        Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
      },
      onError: (error) {
        if (mounted)
          setState(() => _pdfError = 'Could not display these notes.');
      },
      onRender: (pages) {
        if (mounted) setState(() => _pdfTotalPages = pages ?? 0);
      },
      onPageChanged: (page, total) {
        if (mounted) {
          setState(() {
            _pdfCurrentPage = page ?? 0;
            if (total != null) _pdfTotalPages = total;
          });
        }
      },
      onViewCreated: (controller) {
        _pdfViewController = controller;
      },
    );
  }

  /// Prev/Next page buttons plus a "page X of Y" indicator.
  Widget _buildPdfPageControls(Color primaryColor) {
    final canPrev = _pdfCurrentPage > 0;
    final canNext = _pdfCurrentPage < _pdfTotalPages - 1;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: canPrev
              ? () => _pdfViewController?.setPage(_pdfCurrentPage - 1)
              : null,
          icon: Icon(Icons.chevron_left,
              color: canPrev ? Colors.white : Colors.white24),
          tooltip: 'Previous page',
        ),
        Text(
          'Page ${_pdfCurrentPage + 1} of $_pdfTotalPages',
          style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
              fontWeight: FontWeight.w600),
        ),
        IconButton(
          onPressed: canNext
              ? () => _pdfViewController?.setPage(_pdfCurrentPage + 1)
              : null,
          icon: Icon(Icons.chevron_right,
              color: canNext ? Colors.white : Colors.white24),
          tooltip: 'Next page',
        ),
      ],
    );
  }

  /// Expands the PDF to a dedicated full-screen page, hiding the rest of the
  /// lesson (video, buttons, etc.) so reading is distraction-free.
  void _openFullscreenPdf() {
    if (_pdfLocalPath == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullscreenPdfScreen(
          path: _pdfLocalPath!,
          title: _lesson?.title ?? 'Lesson Notes',
          initialPage: _pdfCurrentPage,
        ),
      ),
    );
  }
}

/// Full-screen native PDF viewer used by the "expand" button — takes over
/// the entire screen (no video, no action buttons) so the document is as
/// readable as possible, with its own page navigation and a "minimize"
/// button to return to the lesson screen exactly as it was.
class _FullscreenPdfScreen extends StatefulWidget {
  final String path;
  final String title;
  final int initialPage;

  const _FullscreenPdfScreen(
      {required this.path, required this.title, this.initialPage = 0});

  @override
  State<_FullscreenPdfScreen> createState() => _FullscreenPdfScreenState();
}

class _FullscreenPdfScreenState extends State<_FullscreenPdfScreen> {
  PDFViewController? _controller;
  int _currentPage = 0;
  int _totalPages = 0;

  @override
  Widget build(BuildContext context) {
    final canPrev = _currentPage > 0;
    final canNext = _currentPage < _totalPages - 1;
    return Scaffold(
      backgroundColor: const Color(0xFF071D43),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C2B64),
        foregroundColor: Colors.white,
        title: Text(widget.title, overflow: TextOverflow.ellipsis),
        leading: IconButton(
          icon: const Icon(Icons.fullscreen_exit),
          tooltip: 'Minimize',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: PDFView(
        filePath: widget.path,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: true,
        pageFling: true,
        pageSnap: false,
        fitPolicy: FitPolicy.WIDTH,
        defaultPage: widget.initialPage,
        gestureRecognizers: {
          Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
        },
        onRender: (pages) {
          if (mounted) setState(() => _totalPages = pages ?? 0);
        },
        onPageChanged: (page, total) {
          if (mounted) {
            setState(() {
              _currentPage = page ?? 0;
              if (total != null) _totalPages = total;
            });
          }
        },
        onViewCreated: (controller) {
          _controller = controller;
        },
      ),
      bottomNavigationBar: _totalPages > 0
          ? Container(
              color: const Color(0xFF0C2B64),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: canPrev
                        ? () => _controller?.setPage(_currentPage - 1)
                        : null,
                    icon: Icon(Icons.chevron_left,
                        color: canPrev ? Colors.white : Colors.white24),
                  ),
                  Text(
                    'Page ${_currentPage + 1} of $_totalPages',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    onPressed: canNext
                        ? () => _controller?.setPage(_currentPage + 1)
                        : null,
                    icon: Icon(Icons.chevron_right,
                        color: canNext ? Colors.white : Colors.white24),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}
