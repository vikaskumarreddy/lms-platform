import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
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

  /// True when the target URL points at a PDF that the in-app WebView cannot
  /// render natively (Android WebView shows a blank page for raw PDFs).
  bool get _isPdf {
    final path = widget.url.toLowerCase();
    final cut = path.split('?').first;
    return cut.endsWith('.pdf') || path.contains('blob:') && path.contains('pdf');
  }

  /// For PDFs we load the Google Docs viewer wrapper, which renders the PDF
  /// inside the WebView. The original URL is still used for the external-open
  /// fallback so the OS can open it in a native PDF viewer.
  String get _effectiveUrl {
    if (!_isPdf) return widget.url;
    return 'https://docs.google.com/viewer?embedded=true&url=${Uri.encodeComponent(widget.url)}';
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
          backgroundColor: const Color(0xFF0F172A),
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
        backgroundColor: const Color(0xFF0F172A),
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
            tooltip: _isPdf ? 'Open in external PDF viewer' : 'Open externally',
            onPressed: _openExternally,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading)
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.grey.shade200,
              color: const Color(0xFFEAB308),
              minHeight: 2,
            ),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(_effectiveUrl)),
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
      ),
    );
  }
}