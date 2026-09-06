import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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
  bool _videoLoadFailed = false;
  int _videoRetryKey = 0;

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
    setState(() { _pdfLoading = true; _pdfError = null; _pdfLocalPath = null; });
    try {
      final url = _absoluteMediaUrl(pdfUrl);
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
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
      if (mounted) setState(() => _pdfError = 'Could not load the notes. Check your connection and try again.');
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
          const SnackBar(content: Text('No PDF notes available for this lesson')),
        );
      }
      return;
    }
    setState(() => _pdfSaving = true);
    try {
      String? path = _pdfLocalPath;
      if (path == null) {
        final url = _absoluteMediaUrl(pdfUrl);
        final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
        if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
          throw Exception('download failed');
        }
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/lesson_notes_${widget.lessonId}.pdf');
        await file.writeAsBytes(response.bodyBytes, flush: true);
        path = file.path;
      }
      final safeName = (_lesson?.title ?? 'Lesson Notes').replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim();
      await Share.shareXFiles(
        [XFile(path, name: '${safeName.isEmpty ? 'lesson_notes' : safeName}.pdf')],
        text: _lesson?.title ?? 'Lesson Notes',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not download this PDF. Check your connection and try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _pdfSaving = false);
    }
  }

  /// Builds an embeddable YouTube iframe URL from the video URL.
  String _youtubeEmbedUrl(String videoUrl) {
    final videoId = _extractYouTubeVideoId(videoUrl);
    return 'https://www.youtube.com/embed/$videoId?rel=0&modestbranding=1&playsinline=1';
  }

  /// Self-hosted notes/videos resolve to a relative backend path
  /// (/api/media/{id}/serve or the legacy /api/pdf-notes/{id}/file).
  /// ApiService.baseUrl already ends in "/api", so naively concatenating
  /// produced ".../api/api/media/..." (404/403 from the server) — strip the
  /// duplicated "/api" prefix from the relative path before joining.
  ///
  /// Also appends ngrok-skip-browser-warning=true when the API is tunnelled
  /// through ngrok's free tier: without it, the *first* request from a given
  /// client gets ngrok's own HTML interstitial page back instead of the real
  /// response — fatal for a <video src>/<iframe src> fetch, which has no way
  /// to click through a warning page.
  String _absoluteMediaUrl(String url) {
    if (!url.startsWith('/')) return url;
    var path = url;
    if (path.startsWith('/api/')) path = path.substring(4); // drop leading "/api"
    final full = '${ApiService.baseUrl}$path';
    if (full.contains('ngrok-free.dev') || full.contains('ngrok.io') || full.contains('ngrok.app')) {
      final sep = full.contains('?') ? '&' : '?';
      return '$full${sep}ngrok-skip-browser-warning=true';
    }
    return full;
  }

  /// A minimal HTML5 <video> page for self-hosted files (uploaded through
  /// Media & Files). Loaded via loadData() so no separate hosting/CORS setup
  /// is needed — the video byte URL is fetched directly by the <video> tag.
  /// The <video> tag's own onerror reports back through a JS handler because
  /// InAppWebView's onReceivedError only fires for main-frame navigation
  /// failures — it never fires for a sub-resource (the video src) failing
  /// inside a successfully-loaded data: page, which is why a missing/expired
  /// file previously just sat at a silent, un-erroring 0:00.
  String _selfHostedVideoHtml(String videoUrl) {
    return '''
<!DOCTYPE html>
<html><head><meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
  html, body { margin:0; padding:0; background:#000; height:100%; }
  video { width:100%; height:100%; object-fit:contain; background:#000; }
</style></head>
<body>
  <video controls autoplay playsinline src="$videoUrl"
    onerror="window.flutter_inappwebview.callHandler('videoError', this.error ? this.error.code : -1)"></video>
</body></html>
''';
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

    final hasVideo = lesson.videoUrl.trim().isNotEmpty;

    if (lesson.isLocked) {
      return _buildLockedLessonBody(lesson, primaryColor, secondaryColor);
    }

    return Scaffold(
      appBar: CommonHeader(showBackButton: true, title: lesson.title),
      body: SafeArea(
        child: Stack(
          children: [
            // ── Base layer: the PDF notes occupy the ENTIRE page ──
            // Students read a full-height document; the video no longer
            // reserves a fixed strip at the top.
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
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: primaryColor),
                        ),
                      ),
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
                ),
                const SizedBox(height: 12),
                Expanded(child: _buildPdfNotesSection(primaryColor, fill: true)),
                _buildActionButtons(lesson, primaryColor, secondaryColor),
              ],
            ),
            // ── Floating draggable video (YouTube-style picture-in-picture) ──
            if (hasVideo && !_videoHidden) _buildFloatingVideo(lesson),
            if (hasVideo && _videoHidden) _buildRestoreVideoChip(),
          ],
        ),
      ),
    );
  }

  /// Locked lessons keep the classic stacked layout — the video frame (locked)
  /// followed by the locked-notes notice and the action buttons.
  Widget _buildLockedLessonBody(Lesson lesson, Color primaryColor, Color secondaryColor) {
    return Scaffold(
      appBar: CommonHeader(showBackButton: true, title: lesson.title),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Video player (locked for this subscription tier) ──
          if (lesson.videoUrl.trim().isNotEmpty)
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
                  : _videoLoadFailed
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, color: Colors.grey.shade400, size: 48),
                              const SizedBox(height: 12),
                              Text('Video failed to load', style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
                              const SizedBox(height: 12),
                              TextButton.icon(
                                onPressed: () => setState(() {
                                  _videoLoadFailed = false;
                                  _videoRetryKey++;
                                }),
                                icon: const Icon(Icons.refresh, color: Colors.white),
                                label: const Text('Retry', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        )
                      : lesson.videoSource == 'SELF'
                          // Self-hosted upload (Media & Files): play the raw
                          // video file natively via an HTML5 <video> tag instead
                          // of forcing it through YouTube-embed logic, which
                          // silently fell back to an unrelated dummy video.
                          ? InAppWebView(
                              key: ValueKey(_videoRetryKey),
                              initialData: InAppWebViewInitialData(
                                data: _selfHostedVideoHtml(_absoluteMediaUrl(lesson.videoUrl)),
                                mimeType: 'text/html',
                                encoding: 'utf-8',
                              ),
                              initialSettings: InAppWebViewSettings(
                                javaScriptEnabled: true,
                                allowsInlineMediaPlayback: true,
                                mediaPlaybackRequiresUserGesture: false,
 useHybridComposition: true,
                                transparentBackground: false,
                              ),
                              onWebViewCreated: (controller) {
                                controller.addJavaScriptHandler(
                                  handlerName: 'videoError',
                                  callback: (args) {
                                    if (mounted) setState(() => _videoLoadFailed = true);
                                  },
                                );
                              },
                              onReceivedError: (controller, request, error) {
                                if (request.isForMainFrame ?? true) {
                                  setState(() => _videoLoadFailed = true);
                                }
                              },
                            )
                          : InAppWebView(
                              key: ValueKey(_videoRetryKey),
                              initialUrlRequest: URLRequest(
                                url: WebUri(_youtubeEmbedUrl(lesson.videoUrl)),
                              ),
                              initialSettings: InAppWebViewSettings(
                                javaScriptEnabled: true,
                                allowsInlineMediaPlayback: true,
                                mediaPlaybackRequiresUserGesture: false,
 useHybridComposition: true,
                                transparentBackground: false,
                              ),
                              onReceivedError: (controller, request, error) {
                                if (request.isForMainFrame ?? true) {
                                  setState(() => _videoLoadFailed = true);
                                }
                              },
                            ),
            ),
          ),
          if (lesson.videoUrl.trim().isNotEmpty) const SizedBox(height: 16),
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

          // ── Lesson Notes (the lesson's PDF, rendered natively in place) ──
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
            _buildPdfNotesSection(primaryColor),
          const SizedBox(height: 20),

          // ── Action buttons (shared with the floating-video layout) ──
          _buildActionButtons(lesson, primaryColor, secondaryColor),
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
  Widget _buildPdfNotesSection(Color primaryColor, {bool fill = false}) {
    final hasPdf = (_lesson?.pdfNotesUrl ?? '').isNotEmpty;
    if (!hasPdf) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.description_outlined, color: Colors.grey.shade400),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No notes have been added for this lesson yet.',
                style: TextStyle(color: Colors.grey.shade600, height: 1.5),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Lesson Notes',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: primaryColor),
              ),
              const Spacer(),
              if (_pdfLoading)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              if (_pdfLocalPath != null && _pdfError == null)
                IconButton(
                  onPressed: _openFullscreenPdf,
                  icon: const Icon(Icons.fullscreen),
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
                  const Icon(Icons.error_outline, size: 40, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(_pdfError!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _loadPdfInline,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            )
          else if (_pdfLocalPath == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            if (fill)
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildPdfView(_pdfLocalPath!),
                ),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 520,
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
  Widget _buildActionButtons(Lesson lesson, Color primaryColor, Color secondaryColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              // Download PDF button — saves the notes to the device instead
              // of opening a viewer (the notes render inline above already).
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (lesson.isLocked || _pdfSaving || (lesson.pdfNotesUrl.isEmpty)) ? null : _downloadPdf,
                  icon: _pdfSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.download, size: 18),
                  label: Text(_pdfSaving ? 'Saving...' : 'Download PDF'),
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

  /// YouTube-style draggable video popup. Floats above the full-page PDF at
  /// the bottom-right by default, can be dragged anywhere, resized between
  /// compact and full-width (double-tap or the expand button), and closed —
  /// after which a restore chip brings it back. The [KeyedSubtree] with
  /// [_videoKey] keeps the WebView Element alive across drags/resizes so
  /// playback is never interrupted.
  Widget _buildFloatingVideo(Lesson lesson) {
    final size = MediaQuery.of(context).size;
    final double w = _videoExpanded ? size.width - 24 : 224.0;
    final double h = _videoExpanded ? w * 9 / 16 : 132.0;
    // Default position: lower half of the screen (above the action buttons).
    _videoOffset ??= Offset(size.width - w - 16, size.height * 0.55);
    final double dx = _videoOffset!.dx.clamp(0.0, (size.width - w).clamp(0.0, double.infinity));
    final double dy = _videoOffset!.dy.clamp(0.0, (size.height - h).clamp(0.0, double.infinity));
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
                      onTap: () => setState(() => _videoExpanded = !_videoExpanded),
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
  Widget _pipButton(IconData icon, {required String tooltip, required VoidCallback onTap}) {
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
  Widget _buildRestoreVideoChip() {
    return Positioned(
      right: 16,
      bottom: 96,
      child: FloatingActionButton(
        heroTag: 'restoreLessonVideo',
        tooltip: 'Show video',
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
            Text('Video failed to load', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
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
    if (lesson.videoSource == 'SELF') {
      // Self-hosted upload (Media & Files): play the raw video file natively
      // via an HTML5 <video> tag instead of forcing it through YouTube-embed
      // logic, which silently fell back to an unrelated dummy video.
      return InAppWebView(
        key: ValueKey('self_$_videoRetryKey'),
        initialData: InAppWebViewInitialData(
          data: _selfHostedVideoHtml(_absoluteMediaUrl(lesson.videoUrl)),
          mimeType: 'text/html',
          encoding: 'utf-8',
        ),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          allowsInlineMediaPlayback: true,
          mediaPlaybackRequiresUserGesture: false,
 useHybridComposition: true,
          transparentBackground: false,
        ),
        onWebViewCreated: (controller) {
          controller.addJavaScriptHandler(
            handlerName: 'videoError',
            callback: (args) {
              if (mounted) setState(() => _videoLoadFailed = true);
            },
          );
        },
        onReceivedError: (controller, request, error) {
          if (request.isForMainFrame ?? true) {
            setState(() => _videoLoadFailed = true);
          }
        },
      );
    }
    return InAppWebView(
      key: ValueKey('yt_$_videoRetryKey'),
      initialUrlRequest: URLRequest(
        url: WebUri(_youtubeEmbedUrl(lesson.videoUrl)),
      ),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        allowsInlineMediaPlayback: true,
        mediaPlaybackRequiresUserGesture: false,
 useHybridComposition: true,
        transparentBackground: false,
      ),
      onReceivedError: (controller, request, error) {
        if (request.isForMainFrame ?? true) {
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
        if (mounted) setState(() => _pdfError = 'Could not display these notes.');
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
          onPressed: canPrev ? () => _pdfViewController?.setPage(_pdfCurrentPage - 1) : null,
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Previous page',
        ),
        Text(
          'Page ${_pdfCurrentPage + 1} of $_pdfTotalPages',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
        ),
        IconButton(
          onPressed: canNext ? () => _pdfViewController?.setPage(_pdfCurrentPage + 1) : null,
          icon: const Icon(Icons.chevron_right),
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

  const _FullscreenPdfScreen({required this.path, required this.title, this.initialPage = 0});

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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
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
              color: const Color(0xFF0F172A),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: canPrev ? () => _controller?.setPage(_currentPage - 1) : null,
                    icon: const Icon(Icons.chevron_left, color: Colors.white),
                  ),
                  Text(
                    'Page ${_currentPage + 1} of $_totalPages',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    onPressed: canNext ? () => _controller?.setPage(_currentPage + 1) : null,
                    icon: const Icon(Icons.chevron_right, color: Colors.white),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}

