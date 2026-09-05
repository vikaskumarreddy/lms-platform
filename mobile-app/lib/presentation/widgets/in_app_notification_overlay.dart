import 'package:flutter/material.dart';
import '../../data/models/notification_item.dart';
import '../../core/providers/router_provider.dart';

class InAppNotificationOverlay {
  static OverlayEntry? _current;

  /// Shows the card and leaves it up until the user explicitly dismisses it
  /// (via the close button, backdrop tap, or the action button) -- no
  /// auto-dismiss timer, so it's never missed.
  static void show(NotificationItem notification, {VoidCallback? onAction}) {
    final overlay = _getOverlay();
    if (overlay == null) {
      debugPrint('InAppNotificationOverlay: no OverlayState available, dropping notification "${notification.title}"');
      return;
    }
    _current?.remove();
    _current = null;
    final entry = OverlayEntry(
      builder: (context) => _NotificationOverlayWidget(
        notification: notification,
        onDismiss: () { _current?.remove(); _current = null; },
        onAction: () { _current?.remove(); _current = null; onAction?.call(); },
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }

  /// Resolves the app's single Overlay via the root [Navigator], which is
  /// always mounted once [MaterialApp.router] has built -- unlike
  /// `WidgetsBinding.instance.rootElement`, which has no ancestor Overlay to
  /// find and silently returns nothing.
  static OverlayState? _getOverlay() {
    return rootNavigatorKey.currentState?.overlay;
  }
}

class _NotificationOverlayWidget extends StatefulWidget {
  final NotificationItem notification;
  final VoidCallback onDismiss;
  final VoidCallback onAction;
  const _NotificationOverlayWidget({required this.notification, required this.onDismiss, required this.onAction});
  @override
  State<_NotificationOverlayWidget> createState() => _NotificationOverlayWidgetState();
}

class _NotificationOverlayWidgetState extends State<_NotificationOverlayWidget> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutBack));
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() { _animController.dispose(); super.dispose(); }

  Color _typeColor(String type) {
    switch (type) {
      case 'success': return const Color(0xFF16A34A);
      case 'warning': return const Color(0xFFD97706);
      case 'error': return const Color(0xFFDC2626);
      case 'assignment': return const Color(0xFF2563EB);
      case 'placement': return const Color(0xFF16A34A);
      case 'exam': return const Color(0xFF9333EA);
      case 'course': return const Color(0xFF0D9488);
      default: return const Color(0xFF0F172A);
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'success': return Icons.check_circle;
      case 'warning': return Icons.warning_rounded;
      case 'error': return Icons.error;
      case 'assignment': return Icons.assignment;
      case 'placement': return Icons.work;
      case 'exam': return Icons.quiz;
      case 'course': return Icons.menu_book;
      default: return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notification;
    final typeColor = _typeColor(n.type);
    final typeIcon = _typeIcon(n.type);
    final details = n.detailFields;
    return Positioned.fill(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          children: [
            // Dimmed backdrop, tap to dismiss -- matches the reference modal style.
            Positioned.fill(
              child: GestureDetector(
                onTap: widget.onDismiss,
                child: Container(color: Colors.black.withValues(alpha: 0.55)),
              ),
            ),
            Center(
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 380),
                      child: Material(
                        elevation: 20, shadowColor: Colors.black45, borderRadius: BorderRadius.circular(20),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white, borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: typeColor.withValues(alpha: 0.25), width: 1.5),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _buildHeader(typeIcon),
                              _buildContent(n, details, typeColor),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(IconData typeIcon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEAB308).withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFEAB308), width: 1.4),
            ),
            child: Icon(typeIcon, color: const Color(0xFFEAB308), size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('AXISORA FORGE ACADEMY',
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFEAB308),
                letterSpacing: 1.2,
              ),
            ),
          ),
          GestureDetector(
            onTap: widget.onDismiss,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(NotificationItem n, Map<String, String?> details, Color typeColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(n.title, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), height: 1.25)),
          if (n.message.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(n.message, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4)),
          ],
          if (details.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity, padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFDFBF7), borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: details.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Container(
                          width: 6, height: 6,
                          decoration: BoxDecoration(color: typeColor, shape: BoxShape.circle),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 78,
                        child: Text(e.key,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B), height: 1.35)),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(e.value ?? '',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), fontWeight: FontWeight.w500, height: 1.35)),
                      ),
                    ],
                  ),
                )).toList(),
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEAB308), foregroundColor: const Color(0xFF0F172A),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), elevation: 0,
              ),
              child: const Text('VIEW DETAILS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
            ),
          ),
        ],
      ),
    );
  }
}
