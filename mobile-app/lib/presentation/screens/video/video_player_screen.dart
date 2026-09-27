import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/lesson_media.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/widgets/common_header.dart';
import '../../../data/models/lesson.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/offline_manager.dart';
import 'widgets/lesson_ai_chat_sheet.dart';

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
  bool _isOfflineDownloaded = false;
  bool _isDownloadingVideo = false;
  double _downloadProgress = 0.0;
  String? _offlineVideoPath;

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

    try {
      final isDownloaded = await OfflineManager.instance.isLessonVideoDownloaded(widget.lessonId);
      if (isDownloaded && mounted) {
        final path = await OfflineManager.instance.getLocalVideoFilePath(widget.lessonId);
        setState(() {
          _isOfflineDownloaded = true;
          _offlineVideoPath = path;
        });
      }
    } catch (_) {}

    final pdfUrl = _lesson?.pdfNotesUrl;
    if (!(_lesson?.isLocked ?? true) && pdfUrl != null && pdfUrl.isNotEmpty) {
      _loadPdfInline();
    }
  }

  Future<void> _downloadVideo() async {
    final lesson = _lesson;
    if (lesson == null || _isDownloadingVideo) return;
    if (youtubeVideoId(lesson.videoUrl) != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('YouTube streams cannot be downloaded for offline playback.')),
        );
      }
      return;
    }

    setState(() {
      _isDownloadingVideo = true;
      _downloadProgress = 0.0;
    });

    final resolved = resolveLessonVideoSource(lesson, ApiService.baseUrl, token: _mediaToken);
    final file = await OfflineManager.instance.downloadLessonVideo(
      lesson.id,
      resolved.url,
      onProgress: (p) {
        if (mounted) setState(() => _downloadProgress = p);
      },
    );

    if (mounted) {
      setState(() {
        _isDownloadingVideo = false;
        if (file != null) {
          _isOfflineDownloaded = true;
          _offlineVideoPath = file.path;
          _videoRetryKey++;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(file != null
              ? 'Video downloaded for offline playback!'
              : 'Failed to download video. Check your connection.'),
          backgroundColor: file != null ? const Color(0xFF10B981) : Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _deleteDownloadedVideo() async {
    await OfflineManager.instance.deleteDownloadedLessonVideo(widget.lessonId);
    if (mounted) {
      setState(() {
        _isOfflineDownloaded = false;
        _offlineVideoPath = null;
        _videoRetryKey++;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offline video removed.')),
      );
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

  Future<void> _completeAndNavigateNext() async {
    if (_togglingComplete) return;

    if (!_isCompleted) {
      await _toggleComplete();
    }

    if (!mounted) return;

    final nextId = _lesson?.nextLessonId;
    if (nextId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Text('🎉 ', style: TextStyle(fontSize: 18)),
              Expanded(
                child: Text(
                  'Lesson completed! Loading: ${_lesson?.nextLessonTitle ?? "Next Lesson"}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LessonPlayerScreen(lessonId: nextId),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Text('🏆 ', style: TextStyle(fontSize: 18)),
              Expanded(
                child: Text(
                  'Congratulations! You have completed all lessons in this course!',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
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

    if (kIsWeb) {
      final url = _absoluteMediaUrl(pdfUrl);
      if (mounted) {
        setState(() {
          _pdfLocalPath = url;
          _pdfLoading = false;
        });
      }
      return;
    }

    // Reuse persistently cached PDF from local storage if already retrieved
    try {
      final isCached = await OfflineManager.instance.isPdfCached(widget.lessonId);
      if (isCached) {
        final cachedPath = await OfflineManager.instance.getCachedPdfFilePath(widget.lessonId);
        if (mounted) {
          setState(() {
            _pdfLocalPath = cachedPath;
            _pdfLoading = false;
          });
          return;
        }
      }
    } catch (_) {}

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
      final path = await OfflineManager.instance.saveCachedPdf(widget.lessonId, bytes);
      if (mounted) setState(() => _pdfLocalPath = path);
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
  /// identically on Android and iOS. On Web, opens/downloads directly.
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

    if (kIsWeb) {
      final url = _absoluteMediaUrl(pdfUrl);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      return;
    }

    setState(() => _pdfSaving = true);
    try {
      String? path = _pdfLocalPath;
      if (path == null) {
        final isCached = await OfflineManager.instance.isPdfCached(widget.lessonId);
        if (isCached) {
          path = await OfflineManager.instance.getCachedPdfFilePath(widget.lessonId);
        } else {
          final url = _absoluteMediaUrl(pdfUrl);
          final response =
              await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
          if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
            throw Exception('download failed');
          }
          path = await OfflineManager.instance.saveCachedPdf(widget.lessonId, response.bodyBytes);
        }
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
      actions: [
        _buildAiHeaderButton(lesson),
        IconButton(
          tooltip: isNavBarHidden ? 'Show bottom navigation' : 'Hide bottom navigation',
          icon: Icon(
            isNavBarHidden ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
            color: isNavBarHidden ? const Color(0xFF27D9D3) : Colors.white70,
            size: 22,
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            ref.read(shellNavBarHiddenProvider.notifier).state = !isNavBarHidden;
          },
        ),
      ],
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
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
                  const SizedBox(height: 8),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _buildPdfNotesSection(primaryColor,
                          fill: true, isNavBarHidden: isNavBarHidden),
                    ),
                  ),
                  _buildActionButtons(lesson, primaryColor, secondaryColor,
                      isNavBarHidden: isNavBarHidden),
                ],
              ),
              // ── Floating draggable video (YouTube-style picture-in-picture) ──
              if (hasVideo && !_videoHidden)
                _buildFloatingVideo(lesson, isNavBarHidden, constraints: constraints),
              if (hasVideo && _videoHidden)
                _buildRestoreVideoChip(isNavBarHidden),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAiHeaderButton(Lesson lesson) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF27D9D3), Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF27D9D3).withOpacity(0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => LessonAiChatSheet.show(
            context,
            lesson,
            localPdfPath: _pdfLocalPath,
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                SizedBox(width: 4),
                Text(
                  'Ask AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
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
      actions: [
        _buildAiHeaderButton(lesson),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
          color: const Color(0xFF0C2B64).withOpacity(0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1E4E8C).withOpacity(0.35)),
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

    Widget content;
    if (_pdfError != null) {
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.white54),
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
      );
    } else if (_pdfLocalPath == null) {
      content = const Center(
        child: CircularProgressIndicator(color: Color(0xFF27D9D3)),
      );
    } else {
      if (kIsWeb) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isNarrow = screenWidth < 500;
        final hasVideo = (_lesson?.videoUrl.trim().isNotEmpty ?? false);
        content = Column(
          children: [
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0C2B64).withOpacity(0.85),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.description_rounded, size: 16, color: Color(0xFF27D9D3)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isNarrow ? 'Notes (PDF)' : 'Lesson Notes (PDF)',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasVideo) ...[
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        setState(() {
                          _videoHidden = !_videoHidden;
                          if (!_videoHidden) _videoOffset = null;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(
                          color: _videoHidden
                              ? const Color(0xFF27D9D3).withOpacity(0.25)
                              : Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _videoHidden
                                ? const Color(0xFF27D9D3)
                                : Colors.white24,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _videoHidden
                                  ? Icons.ondemand_video_rounded
                                  : Icons.videocam_off_rounded,
                              color: _videoHidden
                                  ? const Color(0xFF27D9D3)
                                  : Colors.white70,
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _videoHidden ? 'Video' : 'Hide',
                              style: TextStyle(
                                color: _videoHidden
                                    ? const Color(0xFF27D9D3)
                                    : Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                  ],
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      backgroundColor: Colors.white.withOpacity(0.12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: _openFullscreenPdf,
                    icon: const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 13),
                    label: Text(
                      isNarrow ? 'Tab' : 'New Tab',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 5),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      backgroundColor: const Color(0xFF27D9D3).withOpacity(0.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: _downloadPdf,
                    icon: const Icon(Icons.download_rounded, color: Color(0xFF27D9D3), size: 13),
                    label: Text(
                      isNarrow ? 'Save' : 'Download',
                      style: const TextStyle(
                          color: Color(0xFF27D9D3), fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                child: _buildPdfView(_pdfLocalPath!),
              ),
            ),
          ],
        );
      } else {
        content = Stack(
          children: [
            // Native PDF View stretches to fill the entire container
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _buildPdfView(_pdfLocalPath!),
              ),
            ),
            // Transparent floating controls overlay at top-right
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_pdfLoading)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF27D9D3)),
                      ),
                    ),
                  Material(
                    color: Colors.black.withOpacity(0.5),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _openFullscreenPdf,
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.fullscreen, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Transparent floating page navigation pill overlay at bottom
            if (_pdfTotalPages > 0)
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Center(
                  child: _buildPdfPageControls(primaryColor),
                ),
              ),
          ],
        );
      }
    }

    if (fill) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0C2B64).withOpacity(0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1E4E8C).withOpacity(0.35)),
        ),
        clipBehavior: Clip.antiAlias,
        child: content,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0C2B64).withOpacity(0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E4E8C).withOpacity(0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      height: isNavBarHidden
          ? (MediaQuery.of(context).size.height * 0.78).clamp(650.0, 950.0)
          : 540.0,
      child: content,
    );
  }

  /// Download / Bookmark / Share / Mark-complete buttons.
  /// On Web (kIsWeb), "Download PDF" and "Save Video Offline" are hidden and
  /// "Add to Bookmarks" and "Complete Lesson" are placed in the same row to save space.
  Widget _buildActionButtons(
      Lesson lesson, Color primaryColor, Color secondaryColor,
      {required bool isNavBarHidden}) {
    final hasVideo = lesson.videoUrl.trim().isNotEmpty;

    if (kIsWeb) {
      return AnimatedPadding(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
        child: Row(
          children: [
            Expanded(
              flex: 40,
              child: _buildBookmarkCard(lesson),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 60,
              child: _buildCompleteLessonCard(lesson),
            ),
          ],
        ),
      );
    }

    return AnimatedPadding(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                flex: 38,
                child: _buildDownloadPdfCard(lesson),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 36,
                child: _buildBookmarkCard(lesson),
              ),
              if (hasVideo && !lesson.isLocked) ...[
                const SizedBox(width: 8),
                Expanded(
                  flex: 26,
                  child: _buildSaveOfflineCard(lesson),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          _buildCompleteLessonCard(lesson),
        ],
      ),
    );
  }

  Widget _buildDownloadPdfCard(Lesson lesson) {
    return Material(
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: (lesson.isLocked || _pdfSaving || lesson.pdfNotesUrl.isEmpty)
              ? null
              : _downloadPdf,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                if (_pdfSaving)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
                  const Icon(Icons.file_download_outlined,
                      color: Colors.white, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Download PDF',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _pdfSaving ? 'Saving...' : 'Save to your device',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 9.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookmarkCard(Lesson lesson) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: lesson.isLocked ? null : _toggleBookmark,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFDBEAFE), width: 1.2),
          ),
          child: Row(
            children: [
              Icon(
                _isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: const Color(0xFF2563EB),
                size: 20,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _isBookmarked ? 'Bookmarked' : 'Add to Bookmarks',
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Quick access later',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 9.5,
                        ),
                      ),
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

  Widget _buildSaveOfflineCard(Lesson lesson) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _isDownloadingVideo
            ? null
            : _isOfflineDownloaded
                ? _deleteDownloadedVideo
                : _downloadVideo,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isOfflineDownloaded
                  ? const Color(0xFF10B981).withOpacity(0.4)
                  : const Color(0xFFDBEAFE),
              width: 1.2,
            ),
            color: _isOfflineDownloaded
                ? const Color(0xFF10B981).withOpacity(0.08)
                : Colors.white,
          ),
          child: Row(
            children: [
              if (_isDownloadingVideo)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    value: _downloadProgress > 0 ? _downloadProgress : null,
                    strokeWidth: 2,
                    color: const Color(0xFF27D9D3),
                  ),
                )
              else
                Icon(
                  _isOfflineDownloaded
                      ? Icons.offline_pin
                      : Icons.download_for_offline_outlined,
                  color: _isOfflineDownloaded
                      ? const Color(0xFF10B981)
                      : const Color(0xFF2563EB),
                  size: 19,
                ),
              const SizedBox(width: 5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _isDownloadingVideo
                            ? '${(_downloadProgress * 100).toInt()}%'
                            : _isOfflineDownloaded
                                ? 'Saved'
                                : 'Save Offline',
                        style: TextStyle(
                          color: _isOfflineDownloaded
                              ? const Color(0xFF10B981)
                              : const Color(0xFF1E293B),
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _isOfflineDownloaded
                            ? 'Tap to remove'
                            : 'Watch offline',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 9.5,
                        ),
                      ),
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

  Widget _buildCompleteLessonCard(Lesson lesson) {
    return Material(
      color: const Color(0xFFECFDF5),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: (lesson.isLocked || _togglingComplete)
            ? null
            : _completeAndNavigateNext,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFA7F3D0), width: 1.2),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isCompleted
                      ? const Color(0xFF059669)
                      : Colors.transparent,
                  border: _isCompleted
                      ? null
                      : Border.all(color: const Color(0xFF059669), width: 2),
                ),
                child: _togglingComplete
                    ? const Center(
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF059669),
                          ),
                        ),
                      )
                    : Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: _isCompleted
                            ? Colors.white
                            : const Color(0xFF059669),
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _isCompleted ? 'Lesson Completed' : 'Complete Lesson',
                        style: const TextStyle(
                          color: Color(0xFF065F46),
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _isCompleted
                            ? "Completed! Tap to review."
                            : "Tap to complete & next",
                        style: TextStyle(
                          color: const Color(0xFF047857).withOpacity(0.9),
                          fontSize: 9.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Text('🎉', style: TextStyle(fontSize: 16)),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF059669),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// YouTube-style draggable video popup. Floats above the full-page PDF at
  /// the bottom-right by default, can be dragged anywhere via its top header bar,
  /// resized between compact and expanded modes, and closed —
  /// after which a restore chip brings it back.
  void _toggleVideoExpanded() {
    if (!kIsWeb) {
      try {
        HapticFeedback.lightImpact();
      } catch (_) {}
    }
    setState(() {
      _videoExpanded = !_videoExpanded;
      _videoOffset = null; // Clear manual drag offset so the resized box centers/positions perfectly
    });
  }

  void _closeVideo() {
    if (!kIsWeb) {
      try {
        HapticFeedback.lightImpact();
      } catch (_) {}
    }
    setState(() {
      _videoHidden = true;
    });
  }

  Widget _pipButton(
    IconData icon, {
    required VoidCallback onTap,
    String? semanticLabel,
    Color? backgroundColor,
    Color? iconColor,
  }) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (!kIsWeb) {
              try {
                HapticFeedback.lightImpact();
              } catch (_) {}
            }
            onTap();
          },
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            color: Colors.transparent, // Entire 40x40 area captures taps
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: backgroundColor ?? Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: (iconColor ?? Colors.white).withOpacity(0.45),
                  width: 1.2,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 16, color: iconColor ?? Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  /// YouTube-style draggable video popup. Floats above the full-page PDF at
  /// the bottom-right by default, can be dragged anywhere via its top header bar,
  /// resized between compact and expanded modes, and closed —
  /// after which a restore chip brings it back.
  Widget _buildFloatingVideo(Lesson lesson, bool isNavBarHidden,
      {BoxConstraints? constraints}) {
    final size = MediaQuery.of(context).size;
    final double availableWidth = constraints?.maxWidth ?? size.width;
    final double availableHeight = constraints?.maxHeight ?? size.height;
    final bool isSmallScreen = availableWidth < 600;

    final double maxW = (availableWidth - 20).clamp(260.0, 780.0);
    // On mobile devices, compact mode scales to 68% of screen width so it doesn't block the PDF
    final double compactW = isSmallScreen
        ? (availableWidth * 0.68).clamp(210.0, 275.0)
        : 330.0;
    final double w = _videoExpanded ? maxW : compactW;
    final double h = (w * 9 / 16) + 40.0; // 16:9 aspect ratio + 40px top bar

    final double maxLeft = (availableWidth - w).clamp(0.0, double.infinity);
    final double maxTop = (availableHeight - h - (isNavBarHidden ? 8.0 : 16.0)).clamp(0.0, double.infinity);

    final double defaultLeft = _videoExpanded
        ? ((availableWidth - w) / 2).clamp(0.0, maxLeft)
        : (availableWidth - w - 10.0).clamp(0.0, maxLeft);
    final double defaultTop = _videoExpanded
        ? ((availableHeight - h) / 2).clamp(6.0, maxTop)
        : (maxTop * 0.65).clamp(6.0, maxTop);

    // Default position: centered when expanded, right-docked when compact.
    _videoOffset ??= Offset(defaultLeft, defaultTop);
    final double dx = _videoOffset!.dx.clamp(0.0, maxLeft);
    final double dy = _videoOffset!.dy.clamp(0.0, maxTop);

    return Positioned(
      left: dx,
      top: dy,
      width: w,
      height: h,
      child: Material(
        elevation: 14,
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF0F172A),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Top header bar: acts as drag handle and houses explicit expand/shrink and close buttons
            Container(
              height: 40,
              padding: const EdgeInsets.only(left: 10, right: 6),
              color: const Color(0xFF0C2B64),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanUpdate: (details) {
                        setState(() {
                          _videoOffset = Offset(dx + details.delta.dx, dy + details.delta.dy);
                        });
                      },
                      onDoubleTap: _toggleVideoExpanded,
                      child: Row(
                        children: [
                          const Icon(Icons.drag_indicator, size: 16, color: Colors.white54),
                          const SizedBox(width: 4),
                          const Icon(Icons.ondemand_video_rounded, size: 16, color: Color(0xFF27D9D3)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _videoExpanded ? (lesson.title.isNotEmpty ? lesson.title : 'Lesson Video') : 'Video (Drag to move)',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _pipButton(
                    _videoExpanded ? Icons.close_fullscreen_rounded : Icons.open_in_full_rounded,
                    semanticLabel: _videoExpanded ? 'Shrink video' : 'Enlarge video',
                    onTap: _toggleVideoExpanded,
                    backgroundColor: Colors.white.withOpacity(0.18),
                    iconColor: const Color(0xFF27D9D3),
                  ),
                  const SizedBox(width: 4),
                  _pipButton(
                    Icons.close_rounded,
                    semanticLabel: 'Close video',
                    onTap: _closeVideo,
                    backgroundColor: Colors.redAccent.withOpacity(0.32),
                    iconColor: Colors.white,
                  ),
                ],
              ),
            ),
            Expanded(
              child: KeyedSubtree(
                key: _videoKey,
                child: _buildVideoPlayer(lesson),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shown after the popup is closed — restores the floating video.
  Widget _buildRestoreVideoChip(bool isNavBarHidden) {
    return Positioned(
      right: 14,
      bottom: 12,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFF27D9D3),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            if (!kIsWeb) {
              try {
                HapticFeedback.lightImpact();
              } catch (_) {}
            }
            setState(() {
              _videoHidden = false;
              _videoOffset = null; // snap back to default position
            });
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.ondemand_video_rounded, size: 18, color: Color(0xFF071D43)),
                SizedBox(width: 6),
                Text(
                  'Show Video',
                  style: TextStyle(
                    color: Color(0xFF071D43),
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ),
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

    final isOffline = !kIsWeb &&
        _isOfflineDownloaded &&
        _offlineVideoPath != null &&
        _offlineVideoPath!.isNotEmpty;
    final String url;
    final bool youtube;
    final String origin;

    if (isOffline) {
      url = Uri.file(_offlineVideoPath!).toString();
      youtube = false;
      origin = 'file://';
    } else {
      final video = resolveLessonVideoSource(lesson, ApiService.baseUrl,
          token: _mediaToken);
      youtube = video.youtube;
      origin = video.origin;
      url = video.url;
    }

    final isNgrok = origin.contains('ngrok') || url.contains('ngrok');

    return InAppWebView(
      key: ValueKey('video_${_videoRetryKey}_${isOffline ? 'offline' : 'online'}'),
      initialData: InAppWebViewInitialData(
        data: videoDocument(url, youtube: youtube),
        baseUrl: isOffline ? WebUri('file:///') : WebUri('$origin/'),
        mimeType: 'text/html',
        encoding: 'utf-8',
      ),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        allowsInlineMediaPlayback: true,
        mediaPlaybackRequiresUserGesture: false,
        useHybridComposition: false,
        allowFileAccess: true,
        allowFileAccessFromFileURLs: true,
        allowUniversalAccessFromFileURLs: true,
        mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
        useWideViewPort: true,
        cacheEnabled: true,
        // Only set custom agent for ngrok URLs; default Chromium UA enables native media and S3 streaming
        userAgent: (youtube || !isNgrok) ? null : 'LMSStudentMedia/1.0',
      ),
      onWebViewCreated: (controller) {
        if (!kIsWeb) {
          try {
            controller.addJavaScriptHandler(
                handlerName: 'videoError',
                callback: (args) {
                  if (mounted) setState(() => _videoLoadFailed = true);
                });
          } catch (_) {}
        }
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
    if (kIsWeb) {
      final viewerUrl = Uri.base.resolve('/pdf_viewer.html?file=${Uri.encodeComponent(path)}').toString();
      return InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(viewerUrl)),
        initialSettings: InAppWebViewSettings(
          supportMultipleWindows: false,
          javaScriptEnabled: true,
          allowsInlineMediaPlayback: true,
        ),
      );
    }
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

  /// Prev/Next page buttons plus a "page X of Y" indicator, rendered as a
  /// transparent floating glass pill over the PDF view.
  Widget _buildPdfPageControls(Color primaryColor) {
    final canPrev = _pdfCurrentPage > 0;
    final canNext = _pdfCurrentPage < _pdfTotalPages - 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.58),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: canPrev
                ? () => _pdfViewController?.setPage(_pdfCurrentPage - 1)
                : null,
            icon: Icon(Icons.chevron_left_rounded,
                size: 20, color: canPrev ? Colors.white : Colors.white24),
            tooltip: 'Previous page',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '${_pdfCurrentPage + 1} / $_pdfTotalPages',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: canNext
                ? () => _pdfViewController?.setPage(_pdfCurrentPage + 1)
                : null,
            icon: Icon(Icons.chevron_right_rounded,
                size: 20, color: canNext ? Colors.white : Colors.white24),
            tooltip: 'Next page',
          ),
        ],
      ),
    );
  }

  /// Expands the PDF to a dedicated full-screen page, hiding the rest of the
  /// lesson (video, buttons, etc.) so reading is distraction-free.
  /// On Web, opens the PDF directly in a new browser tab for native zoom, print, and search.
  void _openFullscreenPdf() {
    final path = _pdfLocalPath;
    if (path == null) return;
    if (kIsWeb) {
      final viewerUrl = Uri.base.resolve('/pdf_viewer.html?file=${Uri.encodeComponent(path)}').toString();
      launchUrl(Uri.parse(viewerUrl), webOnlyWindowName: '_blank');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullscreenPdfScreen(
          path: path,
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
      extendBodyBehindAppBar: !kIsWeb,
      appBar: AppBar(
        backgroundColor: kIsWeb ? const Color(0xFF0C2B64) : Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: Text(
            widget.title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Material(
            color: Colors.black.withOpacity(0.5),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.of(context).pop(),
              child: const Icon(Icons.fullscreen_exit, color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
      body: kIsWeb
          ? SafeArea(
              child: InAppWebView(
                initialUrlRequest: URLRequest(
                    url: WebUri(Uri.base.resolve('/pdf_viewer.html?file=${Uri.encodeComponent(widget.path)}').toString())),
                initialSettings: InAppWebViewSettings(
                  supportMultipleWindows: false,
                  javaScriptEnabled: true,
                  allowsInlineMediaPlayback: true,
                ),
              ),
            )
          : Stack(
              children: [
                Positioned.fill(
                  child: PDFView(
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
          ),
          if (_totalPages > 0)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: canPrev ? () => _controller?.setPage(_currentPage - 1) : null,
                        icon: Icon(Icons.chevron_left_rounded, color: canPrev ? Colors.white : Colors.white24, size: 24),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          '${_currentPage + 1} / $_totalPages',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: canNext ? () => _controller?.setPage(_currentPage + 1) : null,
                        icon: Icon(Icons.chevron_right_rounded, color: canNext ? Colors.white : Colors.white24, size: 24),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
