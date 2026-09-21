import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class InAppBrowserScreen extends StatefulWidget {
  final String url;
  final String title;
  const InAppBrowserScreen({super.key, required this.url, required this.title});

  @override
  State<InAppBrowserScreen> createState() => _InAppBrowserScreenState();
}

class _InAppBrowserScreenState extends State<InAppBrowserScreen> {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  double _progress = 0;
  bool _canGoBack = false;
  bool _canGoForward = false;

  // ── PDF (native, no WebView) ──────────────────────────────────
  String? _pdfLocalPath;
  String? _pdfError;
  PDFViewController? _pdfViewController;
  int _pdfCurrentPage = 0;
  int _pdfTotalPages = 0;

  @override
  void initState() {
    super.initState();
    if (_isPdf) _downloadPdf();
  }

  /// True when the target URL points at a PDF. WebViews (this screen's normal
  /// path) render web pages, not PDF byte streams — the Android System
  /// WebView component has no built-in PDF plugin the way the full Chrome
  /// app does, so navigating it straight at PDF bytes just shows a blank
  /// page. PDFs are therefore downloaded and rendered by a real, native PDF
  /// renderer (flutter_pdfview) instead — see _downloadPdf()/build() below.
  ///
  /// Self-hosted files served through /api/media/{id}/serve (Media & Files
  /// uploads) or the legacy /api/pdf-notes/{id}/file never end in ".pdf" —
  /// the extension lives in the Content-Disposition header, not the URL path
  /// — so a plain ".pdf" suffix check missed every self-hosted PDF.
  bool get _isPdf {
    final path = widget.url.toLowerCase();
    final cut = path.split('?').first;
    if (cut.endsWith('.pdf') || (path.contains('blob:') && path.contains('pdf'))) {
      return true;
    }
    return cut.contains('/api/media/') || cut.contains('/api/pdf-notes/');
  }

  /// Downloads the PDF's raw bytes directly (same HTTP GET the device already
  /// does successfully when the URL is opened in Chrome — no WebView, no
  /// Google Docs Viewer, no third-party JS viewer, no server-side hop that
  /// can hit an ngrok interstitial page), writes them to a temp file, and
  /// hands that file to a native PDF renderer.
  Future<void> _downloadPdf() async {
    setState(() { _pdfError = null; _pdfLocalPath = null; });
    try {
      final response = await http.get(Uri.parse(widget.url)).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        setState(() => _pdfError = 'Could not load this PDF (server responded ${response.statusCode}).');
        return;
      }
      final bytes = response.bodyBytes;
      if (bytes.isEmpty) {
        setState(() => _pdfError = 'This PDF appears to be empty.');
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/lesson_pdf_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(bytes, flush: true);
      if (mounted) setState(() => _pdfLocalPath = file.path);
    } catch (e) {
      if (mounted) setState(() => _pdfError = 'Could not load this PDF. Check your connection and try again.');
    }
  }

  Future<void> _openExternally() async {
    try {
      final uri = Uri.parse(widget.url);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No app available to open this link')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open this link')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.url.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          title: Text(
            widget.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text('No URL provided', style: TextStyle(fontSize: 16, color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_canGoBack) {
              _webViewController?.goBack();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: _isLoading ? Colors.white38 : Colors.white),
            onPressed: _isLoading ? null : () => _webViewController?.reload(),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: _canGoForward ? () => _webViewController?.goForward() : null,
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Open externally',
            onPressed: _openExternally,
          ),
          if (_isPdf)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Retry',
              onPressed: _pdfLocalPath == null && _pdfError == null ? null : _downloadPdf,
            ),
          if (_isPdf && _pdfLocalPath != null && _pdfError == null)
            IconButton(
              icon: const Icon(Icons.fullscreen),
              tooltip: 'Expand',
              onPressed: _openFullscreenPdf,
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isPdf ? _buildPdfBody() : _buildWebViewBody(),
      bottomNavigationBar: (_isPdf && _pdfTotalPages > 0)
          ? Container(
              color: Theme.of(context).colorScheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _pdfCurrentPage > 0 ? () => _pdfViewController?.setPage(_pdfCurrentPage - 1) : null,
                    icon: const Icon(Icons.chevron_left, color: Colors.white),
                  ),
                  Text(
                    'Page ${_pdfCurrentPage + 1} of $_pdfTotalPages',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    onPressed: _pdfCurrentPage < _pdfTotalPages - 1 ? () => _pdfViewController?.setPage(_pdfCurrentPage + 1) : null,
                    icon: const Icon(Icons.chevron_right, color: Colors.white),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  /// Expands the PDF to a dedicated full-screen page (no app bar/webview
  /// chrome competing for space), with its own page controls; "Minimize"
  /// returns here exactly as it was.
  void _openFullscreenPdf() {
    if (_pdfLocalPath == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullscreenPdfView(
          path: _pdfLocalPath!,
          title: widget.title,
          initialPage: _pdfCurrentPage,
        ),
      ),
    );
  }

  /// PDFs render fully in-app via a native PDF renderer (flutter_pdfview) —
  /// no WebView, no external app, no third-party viewer, no server-side hop
  /// that can be intercepted by something like an ngrok interstitial page.
  /// The device downloads the exact same bytes it would get opening the URL
  /// in Chrome, then draws real PDF pages locally.
  Widget _buildPdfBody() {
    if (_pdfError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text(_pdfError!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: Colors.grey)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _downloadPdf,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_pdfLocalPath == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return PDFView(
      filePath: _pdfLocalPath!,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: true,
      pageFling: true,
      pageSnap: false,
      fitPolicy: FitPolicy.WIDTH,
      // Claim drag/zoom gestures so the native renderer, not the surrounding
      // Scaffold/body, handles in-page scrolling and pinch-to-zoom.
      gestureRecognizers: {
        Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
      },
      onError: (error) {
        if (mounted) setState(() => _pdfError = 'Could not display this PDF.');
      },
      onRender: (pages) {
        if (mounted) setState(() { _isLoading = false; _pdfTotalPages = pages ?? 0; });
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

  Widget _buildWebViewBody() {
    return Column(
      children: [
        if (_isLoading)
          LinearProgressIndicator(
            value: _progress,
            backgroundColor: Colors.grey.shade200,
            color: Theme.of(context).colorScheme.secondary,
            minHeight: 2,
          ),
        Expanded(
          child: InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(widget.url)),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              domStorageEnabled: true,
              supportMultipleWindows: false,
              useHybridComposition: true,
              javaScriptCanOpenWindowsAutomatically: false,
            ),
            onWebViewCreated: (controller) {
              _webViewController = controller;
            },
            onProgressChanged: (controller, progress) {
              setState(() {
                _progress = progress / 100;
                _isLoading = progress < 100;
              });
            },
            onUpdateVisitedHistory: (controller, url, isReload) async {
              final canGoBack = await controller.canGoBack();
              final canGoForward = await controller.canGoForward();
              if (mounted) {
                setState(() {
                  _canGoBack = canGoBack;
                  _canGoForward = canGoForward;
                });
              }
            },
            onLoadStart: (controller, url) {
              if (mounted) {
                setState(() => _isLoading = true);
              }
            },
            onLoadStop: (controller, url) async {
              final canGoBack = await controller.canGoBack();
              final canGoForward = await controller.canGoForward();
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _canGoBack = canGoBack;
                  _canGoForward = canGoForward;
                });
              }
            },
            onReceivedError: (controller, request, error) {
              if (mounted) {
                setState(() => _isLoading = false);
              }
            },
          ),
        ),
      ],
    );
  }
}

/// Full-screen native PDF viewer used by the "expand" button on the in-app
/// browser's PDF view — hides the browser chrome entirely so the document
/// fills the screen, with its own page navigation and a "minimize" button
/// to return to the browser screen exactly as it was.
class _FullscreenPdfView extends StatefulWidget {
  final String path;
  final String title;
  final int initialPage;

  const _FullscreenPdfView({required this.path, required this.title, this.initialPage = 0});

  @override
  State<_FullscreenPdfView> createState() => _FullscreenPdfViewState();
}

class _FullscreenPdfViewState extends State<_FullscreenPdfView> {
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
        backgroundColor: Theme.of(context).colorScheme.primary,
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
              color: Theme.of(context).colorScheme.primary,
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

