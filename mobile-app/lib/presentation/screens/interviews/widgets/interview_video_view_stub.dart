import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

Widget buildInterviewVideoView({
  required String url,
  required String viewId,
  VoidCallback? onLoaded,
}) {
  if (kIsWeb || InAppWebViewPlatform.instance == null) {
    return Container(
      color: const Color(0xFF071120),
      child: const Center(
        child: Text('WebRTC Video Player', style: TextStyle(color: Colors.white70)),
      ),
    );
  }

  return InAppWebView(
    initialUrlRequest: URLRequest(url: WebUri(url)),
    initialSettings: InAppWebViewSettings(
      javaScriptEnabled: true,
      mediaPlaybackRequiresUserGesture: false,
      allowsInlineMediaPlayback: true,
      useWideViewPort: true,
    ),
    onLoadStop: (controller, uri) {
      if (onLoaded != null) onLoaded();
    },
    onPermissionRequest: (controller, request) async {
      return PermissionResponse(
        resources: request.resources,
        action: PermissionResponseAction.GRANT,
      );
    },
  );
}
