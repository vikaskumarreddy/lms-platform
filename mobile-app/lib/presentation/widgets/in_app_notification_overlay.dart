import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms_student_app/data/models/notification_item.dart';
import '../../core/providers/router_provider.dart';
import '../../core/providers/org_theme_provider.dart';

bool _isReminderNotification(NotificationItem item) =>
    item.type.toLowerCase() == 'reminder' ||
    item.title.toLowerCase().contains('reminder') ||
    (item.actionUrl != null && item.actionUrl!.contains('reminders'));

bool _isPlacementNotification(NotificationItem item) =>
    item.type.toLowerCase() == 'placement' ||
    item.title.toLowerCase().contains('placement') ||
    item.title.toLowerCase().contains('drive') ||
    (item.actionUrl != null && item.actionUrl!.contains('placement'));

bool _isExamNotification(NotificationItem item) =>
    item.type.toLowerCase() == 'exam' ||
    item.title.toLowerCase().contains('exam') ||
    (item.actionUrl != null && item.actionUrl!.contains('exam'));

bool _isAssignmentNotification(NotificationItem item) =>
    item.type.toLowerCase() == 'assignment' ||
    item.title.toLowerCase().contains('assignment') ||
    (item.actionUrl != null && item.actionUrl!.contains('assignment'));

bool _isCourseNotification(NotificationItem item) =>
    item.type.toLowerCase() == 'course' ||
    item.title.toLowerCase().contains('course') ||
    (item.actionUrl != null && item.actionUrl!.contains('course'));

String _categoryBadge(NotificationItem item) {
  if (_isReminderNotification(item)) return 'REMINDER';
  if (_isPlacementNotification(item)) return 'PLACEMENT DRIVE';
  if (_isExamNotification(item)) return 'EXAM ALERT';
  if (_isAssignmentNotification(item)) return 'ASSIGNMENT';
  if (_isCourseNotification(item)) return 'COURSE UPDATE';
  if (item.type.toLowerCase() == 'announcement') return 'ANNOUNCEMENT';
  return 'LMS NOTIFICATION';
}

class InAppNotificationOverlay {
  static OverlayEntry? _current;

  /// Shows the in-app notification popup.
  /// Reminders render a faithful 3D alarm-clock card matching the design reference,
  /// while academic & placement alerts render a luxury dark navy glass card with rich metadata.
  static void show(NotificationItem notification, {VoidCallback? onAction}) {
    final overlay = _getOverlay();
    if (overlay == null) {
      debugPrint(
          'InAppNotificationOverlay: no OverlayState available, dropping notification "${notification.title}"');
      return;
    }
    _current?.remove();
    _current = null;
    final entry = OverlayEntry(
      builder: (context) => _NotificationOverlayWidget(
        notification: notification,
        onDismiss: () {
          _current?.remove();
          _current = null;
        },
        onAction: () {
          _current?.remove();
          _current = null;
          onAction?.call();
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }

  /// Programmatically dismiss the active in-app notification popup.
  static void dismiss() {
    _current?.remove();
    _current = null;
  }

  /// Resolves the app's single Overlay via the root [Navigator].
  static OverlayState? _getOverlay() {
    return rootNavigatorKey.currentState?.overlay;
  }
}

class _NotificationOverlayWidget extends ConsumerStatefulWidget {
  final NotificationItem notification;
  final VoidCallback onDismiss;
  final VoidCallback onAction;

  const _NotificationOverlayWidget({
    required this.notification,
    required this.onDismiss,
    required this.onAction,
  });

  @override
  ConsumerState<_NotificationOverlayWidget> createState() =>
      _NotificationOverlayWidgetState();
}

class _NotificationOverlayWidgetState
    extends ConsumerState<_NotificationOverlayWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _wobbleAnimation;

  @override
  void initState() {
    super.initState();
    // Gentle haptic feedback on popup appearance
    HapticFeedback.mediumImpact();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _scaleAnimation = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    // Subtle alarm ringing wobble effect for the reminder clock
    _wobbleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -0.10).chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -0.10, end: 0.10).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.10, end: -0.05).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -0.05, end: 0.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
    ]).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.2, 1.0)),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orgTheme = ref.watch(orgThemeProvider);
    final n = widget.notification;

    return Positioned.fill(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Frosted blurred backdrop with tap-to-dismiss
            Positioned.fill(
              child: GestureDetector(
                onTap: widget.onDismiss,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.50),
                  ),
                ),
              ),
            ),

            // Notification Card Modal
            Center(
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _isReminderNotification(n)
                        ? _ReminderPopupCard(
                            notification: n,
                            wobbleAnimation: _wobbleAnimation,
                            onAction: widget.onAction,
                            onDismiss: widget.onDismiss,
                          )
                        : _LuxuryGeneralNotificationCard(
                            notification: n,
                            theme: orgTheme,
                            onAction: widget.onAction,
                            onDismiss: widget.onDismiss,
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
}

// ============================================================================
// REMINDER IN-APP POPUP CARD (MATCHING USER REFERENCE IMAGE)
// ============================================================================

class _ReminderPopupCard extends StatelessWidget {
  final NotificationItem notification;
  final Animation<double> wobbleAnimation;
  final VoidCallback onAction;
  final VoidCallback onDismiss;

  const _ReminderPopupCard({
    required this.notification,
    required this.wobbleAnimation,
    required this.onAction,
    required this.onDismiss,
  });

  String _getSubtitle() {
    if (notification.message.isNotEmpty &&
        notification.message.toLowerCase() != 'you have 1 new reminder') {
      return notification.message;
    }
    if (notification.title.isNotEmpty &&
        !notification.title.toLowerCase().startsWith('reminder')) {
      return notification.title;
    }
    return 'You have 1 new reminder';
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Soft 3D elevated white card
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 36,
                  offset: const Offset(0, 14),
                ),
                BoxShadow(
                  color: const Color(0xFFF43F5E).withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(24, 52, 24, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top close button
                Align(
                  alignment: Alignment.topRight,
                  child: GestureDetector(
                    onTap: onDismiss,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded,
                          size: 16, color: Color(0xFF71717A)),
                    ),
                  ),
                ),

                // Bold "Reminder" Title
                const Text(
                  'Reminder',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF18181B),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),

                // Subtitle / message
                Text(
                  _getSubtitle(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF52525B),
                    height: 1.42,
                  ),
                ),

                // Date / Time Chip if present
                if (notification.time != null || notification.date != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFE4E6)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time_rounded,
                            size: 14, color: Color(0xFFE11D48)),
                        const SizedBox(width: 6),
                        Text(
                          [
                            if (notification.date != null) notification.date!,
                            if (notification.time != null) notification.time!,
                          ].join(' • '),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFE11D48),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 22),

                // Vibrant Rose/Crimson "Open" Pill Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF2D55), Color(0xFFE11D48)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE11D48).withValues(alpha: 0.40),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: onAction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                      ),
                      child: const Text(
                        'Open',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Subtle Dismiss Option
                GestureDetector(
                  onTap: onDismiss,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                    child: Text(
                      'Dismiss',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF71717A),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Top Protruding Circular Pedestal with 3D Alarm Clock
          Positioned(
            top: -40,
            child: Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: AnimatedBuilder(
                  animation: wobbleAnimation,
                  builder: (context, child) => Transform.rotate(
                    angle: wobbleAnimation.value,
                    child: child,
                  ),
                  child: CustomPaint(
                    size: const Size(48, 48),
                    painter: _AlarmClock3DPainter(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for a 3D styled golden brass alarm clock with twin bells,
/// top hammer, radial metallic gradient, hour tick dots, and hands at 10:10.
class _AlarmClock3DPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 2);
    final radius = size.width * 0.36;

    // 1. Bottom twin feet at angle
    final legPaint = Paint()
      ..color = const Color(0xFFB45309)
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    final leftLegStart = center + Offset(-radius * 0.68, radius * 0.68);
    final leftLegEnd = leftLegStart + const Offset(-4, 6.5);
    canvas.drawLine(leftLegStart, leftLegEnd, legPaint);

    final rightLegStart = center + Offset(radius * 0.68, radius * 0.68);
    final rightLegEnd = rightLegStart + const Offset(4, 6.5);
    canvas.drawLine(rightLegStart, rightLegEnd, legPaint);

    // 2. Twin bells at top
    final leftBellCenter = center + Offset(-radius * 0.78, -radius * 0.78);
    final bellPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFFEF3C7), Color(0xFFF59E0B), Color(0xFF92400E)],
        stops: [0.0, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: leftBellCenter, radius: radius * 0.40));
    canvas.drawCircle(leftBellCenter, radius * 0.36, bellPaint);

    final rightBellCenter = center + Offset(radius * 0.78, -radius * 0.78);
    final rightBellPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFFEF3C7), Color(0xFFF59E0B), Color(0xFF92400E)],
        stops: [0.0, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: rightBellCenter, radius: radius * 0.40));
    canvas.drawCircle(rightBellCenter, radius * 0.36, rightBellPaint);

    // Bell rim highlights
    final bellRimPaint = Paint()
      ..color = const Color(0xFFFFFBEB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(leftBellCenter, radius * 0.36, bellRimPaint);
    canvas.drawCircle(rightBellCenter, radius * 0.36, bellRimPaint);

    // 3. Top center hammer/handle
    final handlePaint = Paint()
      ..color = const Color(0xFF92400E)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;
    canvas.drawArc(
      Rect.fromCenter(
        center: center + Offset(0, -radius * 1.02),
        width: radius * 0.6,
        height: radius * 0.38,
      ),
      3.14159,
      3.14159,
      false,
      handlePaint,
    );

    // 4. Main clock casing (3D metallic gold radial gradient)
    final bodyShadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(center + const Offset(0, 2.5), radius, bodyShadow);

    final bodyPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFFEF3C7), Color(0xFFFBBF24), Color(0xFFB45309)],
        stops: [0.0, 0.68, 1.0],
      ).createShader(
          Rect.fromCircle(center: center - const Offset(2, 2), radius: radius));
    canvas.drawCircle(center, radius, bodyPaint);

    // 5. White dial face inside
    final dialRadius = radius * 0.77;
    final dialPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, dialRadius, dialPaint);

    final innerBevel = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawCircle(center, dialRadius, innerBevel);

    // 6. Hour tick dots (12 dots)
    final dotPaint = Paint()..color = const Color(0xFF9CA3AF);
    for (int i = 0; i < 12; i++) {
      final angle = (i * 30) * 3.1415926535 / 180;
      final dotPos = center +
          Offset(dialRadius * 0.76 * math.sin(angle),
              -dialRadius * 0.76 * math.cos(angle));
      canvas.drawCircle(dotPos, (i % 3 == 0) ? 1.4 : 0.7, dotPaint);
    }

    // 7. Clock hands at 10:10
    final handPaint = Paint()
      ..color = const Color(0xFF1F2937)
      ..strokeCap = StrokeCap.round;

    // Hour hand pointing to 10
    handPaint.strokeWidth = 2.0;
    const hourAngle = -60 * 3.1415926535 / 180;
    final hourEnd = center +
        Offset(dialRadius * 0.50 * math.sin(hourAngle),
            dialRadius * 0.50 * math.cos(hourAngle));
    canvas.drawLine(center, hourEnd, handPaint);

    // Minute hand pointing to 2
    handPaint.strokeWidth = 1.5;
    const minAngle = 60 * 3.1415926535 / 180;
    final minEnd = center +
        Offset(dialRadius * 0.70 * math.sin(minAngle),
            dialRadius * 0.70 * math.cos(minAngle));
    canvas.drawLine(center, minEnd, handPaint);

    // Center pin
    final pinPaint = Paint()..color = const Color(0xFFE11D48);
    canvas.drawCircle(center, 2.0, pinPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// LUXURY GENERAL NOTIFICATION POPUP (PLACEMENTS, EXAMS, ASSIGNMENTS, ETC.)
// ============================================================================

class _LuxuryGeneralNotificationCard extends StatelessWidget {
  final NotificationItem notification;
  final dynamic theme;
  final VoidCallback onAction;
  final VoidCallback onDismiss;

  const _LuxuryGeneralNotificationCard({
    required this.notification,
    required this.theme,
    required this.onAction,
    required this.onDismiss,
  });

  Color _accentColor() {
    if (_isPlacementNotification(notification)) return const Color(0xFF10B981); // Emerald
    if (_isExamNotification(notification)) return const Color(0xFFF59E0B); // Amber
    if (_isAssignmentNotification(notification)) return const Color(0xFF8B5CF6); // Violet
    if (_isCourseNotification(notification)) return const Color(0xFF27D9D3); // Cyan
    if (notification.type.toLowerCase() == 'announcement') {
      return const Color(0xFF3B82F6); // Blue
    }
    return const Color(0xFF27D9D3);
  }

  IconData _categoryIcon() {
    if (_isPlacementNotification(notification)) return Icons.work_rounded;
    if (_isExamNotification(notification)) return Icons.quiz_rounded;
    if (_isAssignmentNotification(notification)) return Icons.assignment_turned_in_rounded;
    if (_isCourseNotification(notification)) return Icons.menu_book_rounded;
    if (notification.type.toLowerCase() == 'announcement') {
      return Icons.campaign_rounded;
    }
    return Icons.notifications_active_rounded;
  }

  String _ctaText() {
    if (_isPlacementNotification(notification)) return 'VIEW PLACEMENT DRIVE';
    if (_isExamNotification(notification)) return 'VIEW EXAM PAPER';
    if (_isAssignmentNotification(notification)) return 'VIEW ASSIGNMENT';
    if (_isCourseNotification(notification)) return 'VIEW COURSE';
    return 'VIEW DETAILS';
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor();
    final icon = _categoryIcon();
    final details = notification.detailFields;

    return Dismissible(
      key: ValueKey('notif-${notification.id}'),
      direction: DismissDirection.up,
      onDismissed: (_) => onDismiss(),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF0C2B64).withValues(alpha: 0.95),
                    const Color(0xFF071D43).withValues(alpha: 0.97),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: accent.withValues(alpha: 0.40),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: accent.withValues(alpha: 0.22),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row: Category Badge + Timestamp + Close
                  Row(
                    children: [
                      // Glowing circular icon badge
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent.withValues(alpha: 0.16),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.50),
                            width: 1.4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.30),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Icon(icon, color: accent, size: 20),
                      ),
                      const SizedBox(width: 12),

                      // Category chip + tag
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: accent.withValues(alpha: 0.40)),
                              ),
                              child: Text(
                                _categoryBadge(notification),
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Just now',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.50),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Close X
                      GestureDetector(
                        onTap: onDismiss,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.10),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded,
                              size: 16, color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Notification Title
                  Text(
                    notification.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.3,
                    ),
                  ),

                  // Notification Message
                  if (notification.message.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      notification.message,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: Colors.white.withValues(alpha: 0.80),
                        height: 1.4,
                      ),
                    ),
                  ],

                  // Rich Metadata Chip Grid (Company, Role, Package, Venue, Deadline)
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: details.entries.map((entry) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF071D43).withValues(alpha: 0.60),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: accent.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${entry.key}: ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: accent.withValues(alpha: 0.90),
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    entry.value ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),

                  // Action Buttons: Secondary "Dismiss" + Primary Gradient CTA
                  Row(
                    children: [
                      // Secondary "Dismiss"
                      Expanded(
                        flex: 2,
                        child: OutlinedButton(
                          onPressed: onDismiss,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.22)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          child: const Text(
                            'Dismiss',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Primary Glowing Gradient Button
                      Expanded(
                        flex: 4,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: LinearGradient(
                              colors: [
                                accent,
                                accent.withValues(alpha: 0.85),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.35),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: onAction,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    _ctaText(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF041838),
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.arrow_forward_rounded,
                                    size: 15, color: Color(0xFF041838)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
