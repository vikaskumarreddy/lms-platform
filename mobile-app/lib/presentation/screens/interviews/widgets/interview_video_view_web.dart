import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

final Set<String> _registeredViewTypes = {};

Widget buildInterviewVideoView({
  required String url,
  required String viewId,
  VoidCallback? onLoaded,
}) {
  if (!_registeredViewTypes.contains(viewId)) {
    _registeredViewTypes.add(viewId);
    ui_web.platformViewRegistry.registerViewFactory(
      viewId,
      (int id) {
        final iframe = html.IFrameElement()
          ..src = url
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.backgroundColor = '#071120'
          ..allow = 'camera *; microphone *; display-capture *; autoplay *; clipboard-read *; clipboard-write *'
          ..setAttribute('allow', 'camera *; microphone *; display-capture *; autoplay *; clipboard-read *; clipboard-write *')
          ..setAttribute('allowfullscreen', 'true');

        iframe.onLoad.listen((_) {
          if (onLoaded != null) onLoaded();
        });

        return iframe;
      },
    );
  }

  return HtmlElementView(viewType: viewId);
}
