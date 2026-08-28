import 'package:flutter/material.dart';

/// Root [ScaffoldMessengerState] key, wired into [MaterialApp.router] in
/// `main.dart`, so services outside the widget tree (e.g. foreground push
/// notification handling) can surface a SnackBar without needing a
/// [BuildContext] of their own.
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
