// modern_bottom_nav_bar.dart
//
// Drop-in replacement — same constructor signature, same tuple tab format
// ((String, IconData, IconData, String)), same onTap callback. No changes
// needed in MainShellScreen.
//
// CHANGED FROM THE PREVIOUS VERSION:
//   - Every icon now carries its own translucent glass backdrop at all
//     times (not just when centered) — that backdrop is also noticeably
//     thicker (higher opacity + stronger blur + a soft shadow), so icons
//     stay legible over busy page content instead of washing out.
//   - The off-center fade floor was raised (0.35 -> 0.7) so icons never
//     drop to near-invisible; they stay readable while still visually
//     receding from the centered tab.
//   - The scroll-driven pop is a fuller arc now: taller rise (curveHeight),
//     a wider falloff radius so more neighboring icons sit visibly on the
//     curve, and a stronger tilt/scale sweep — reads as a half-circle
//     bow across the row instead of a subtle bump near the center.
//   - Added a curved, blurred glass background behind the whole row,
//     shaped with the EXACT SAME arc math the icons use, so its bulge
//     always lines up with wherever the popped-up tab currently sits.
//
// USAGE — unchanged:
//
//   ModernBottomNavBar(
//     currentIndex: _getCurrentIndex(),
//     tabs: _tabs,
//     onTap: (index) => context.go(_tabs[index].$1),
//   )

import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

/// Floating, background-less navigation: icons scroll freely across the
/// full app width, each carrying its own glassy backdrop; the centered
/// icon pops up, tilts, and expands into a labeled glass pill.
class ModernBottomNavBar extends StatefulWidget {
  final int currentIndex;
  final List<(String, IconData, IconData, String)> tabs;
  final ValueChanged<int> onTap;

  const ModernBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.tabs,
    required this.onTap,
  });

  static const double barHeight = 68;
  static const double bubbleSize = 40;
  static const double bMargin = 0; // no bottom gap

  // Fixed slot width used for layout/scroll math. The pill visually grows
  // past this via OverflowBox as a tab nears the center — it doesn't
  // reflow neighboring slots.
  static const double itemExtent = 128; // reserves full expanded-pill width
  static const double collapsedWidth = 48;
  static const double expandedWidth = 128;

  // How dramatic the arc pop is. Bigger curveHeight + wider arcSpan reads
  // as a genuine half-circle sweep across several icons rather than a
  // single icon popping in place.
  static const double curveHeight = 26;
  static const double minScale = 0.72;
  // How many item-slots on either side of center the arc reaches across
  // before flattening out — wider than before so the bow is visible
  // across more of the row.
  static const double arcSpan = 2.6;

  @override
  State<ModernBottomNavBar> createState() => _ModernBottomNavBarState();
}

class _ModernBottomNavBarState extends State<ModernBottomNavBar> {
  late final ScrollController _scrollController;
  double _scrollGloss = 0.0; // 0..1, brightens each icon's glint while scrolling
  bool _isSettling = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback(
          (_) => _scrollToIndex(widget.currentIndex, animate: false),
    );
  }

  @override
  void didUpdateWidget(covariant ModernBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex && !_isSettling) {
      _scrollToIndex(widget.currentIndex);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToIndex(int index, {bool animate = true}) {
    if (!_scrollController.hasClients) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollToIndex(index, animate: animate));
      return;
    }
    final target = (index * ModernBottomNavBar.itemExtent)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
    if (animate) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(target);
    }
  }

  int get _nearestIndex {
    if (!_scrollController.hasClients) return widget.currentIndex;
    return (_scrollController.offset / ModernBottomNavBar.itemExtent)
        .round()
        .clamp(0, widget.tabs.length - 1);
  }

  Future<void> _snapAndSelect() async {
    final nearest = _nearestIndex;
    _isSettling = true;
    await _scrollController.animateTo(
      nearest * ModernBottomNavBar.itemExtent,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
    _isSettling = false;
    if (nearest != widget.currentIndex) {
      widget.onTap(nearest);
    }
  }

  Future<void> _onTileTap(int index) async {
    _isSettling = true;
    await _scrollController.animateTo(
      index * ModernBottomNavBar.itemExtent,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
    _isSettling = false;
    if (index != widget.currentIndex) {
      widget.onTap(index);
    }
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification && _scrollGloss != 1.0) {
      setState(() => _scrollGloss = 1.0);
    } else if (notification is ScrollEndNotification) {
      if (_scrollGloss != 0.0) setState(() => _scrollGloss = 0.0);
      if (!_isSettling) _snapAndSelect();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return SizedBox(
      // Reserve Android's system navigation area in layout, while keeping
      // the actual custom navbar directly against the system navigation bar.
      height: ModernBottomNavBar.barHeight + bottomInset,
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          height: ModernBottomNavBar.barHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Full app width — no side margins, no max-width cap.
              final barWidth = constraints.maxWidth;
              final sidePadding =
                  (barWidth - ModernBottomNavBar.itemExtent) / 2;

              return NotificationListener<ScrollNotification>(
                onNotification: _onScrollNotification,
                child: Stack(
                  children: [
                    // The curved glass background. It's static — it never
                    // needs the scroll offset, because the bump it traces
                    // is always anchored to the screen's physical center
                    // (that IS what "centered tab" means here); tabs scroll
                    // underneath it, the bump itself doesn't move. It uses
                    // the exact same curveHeight/arcSpan/itemExtent math as
                    // the icons below, so its shape always matches theirs.
                    Positioned.fill(
                      child: IgnorePointer(child: _ArcNavBackground()),
                    ),
                    AnimatedBuilder(
                      // Rebuilds every scroll frame so the arc transform tracks
                      // the finger in real time.
                      animation: _scrollController,
                      builder: (context, _) {
                        final currentOffset = _scrollController.hasClients
                            ? _scrollController.offset
                            : (widget.currentIndex *
                            ModernBottomNavBar.itemExtent);

                        return ListView.builder(
                          controller: _scrollController,
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding:
                          EdgeInsets.symmetric(horizontal: sidePadding),
                          itemCount: widget.tabs.length,
                          itemBuilder: (context, index) {
                            final itemCenter = index *
                                ModernBottomNavBar.itemExtent +
                                ModernBottomNavBar.itemExtent / 2;
                            final viewportCenter =
                                currentOffset + barWidth / 2 - sidePadding;
                            final distance = itemCenter - viewportCenter;
                            final tab = widget.tabs[index];

                            return _GlassTab(
                              distance: distance,
                              scrollGloss: _scrollGloss,
                              icon: tab.$2,
                              activeIcon: tab.$3,
                              label: tab.$4,
                              onTap: () => _onTileTap(index),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Traces the same rise-and-fall curve the icons travel (see
/// [_GlassTab]'s `riseFall`), so the background bump lines up exactly with
/// wherever the centered tab currently sits — a continuous "oval" bar that
/// bulges up at screen-center and settles back down toward the edges,
/// rather than a flat pill.
Path _arcNavPath(Size size) {
  const cornerRadius = 22.0;
  const step = 6.0;
  final center = size.width / 2;

  double topAt(double x) {
    final distance = x - center;
    final slots = (distance / ModernBottomNavBar.itemExtent)
        .clamp(-ModernBottomNavBar.arcSpan, ModernBottomNavBar.arcSpan);
    final angle = (slots / ModernBottomNavBar.arcSpan) * (math.pi / 2);
    return ModernBottomNavBar.curveHeight * (1 - math.cos(angle));
  }

  final path = Path()..moveTo(0, size.height);
  final leftTop = topAt(0);
  path.lineTo(0, leftTop + cornerRadius);
  path.quadraticBezierTo(0, leftTop, cornerRadius, leftTop);
  for (double x = cornerRadius; x <= size.width - cornerRadius; x += step) {
    path.lineTo(x, topAt(x));
  }
  final rightTop = topAt(size.width);
  path.lineTo(size.width - cornerRadius, rightTop);
  path.quadraticBezierTo(size.width, rightTop, size.width, rightTop + cornerRadius);
  path.lineTo(size.width, size.height);
  path.close();
  return path;
}

class _ArcNavClipper extends CustomClipper<Path> {
  const _ArcNavClipper();
  @override
  Path getClip(Size size) => _arcNavPath(size);
  @override
  bool shouldReclip(covariant _ArcNavClipper oldClipper) => false;
}

class _ArcNavPainter extends CustomPainter {
  const _ArcNavPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = _arcNavPath(size);
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withOpacity(0.42),
          Colors.black.withOpacity(0.28),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, fillPaint);

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = Colors.white.withOpacity(0.22);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _ArcNavPainter oldDelegate) => false;
}

/// The curved glass panel itself — blurs whatever page content sits behind
/// the nav bar, then fills the same wavy shape with a translucent dark
/// gradient and traces its edge with a thin light stroke.
class _ArcNavBackground extends StatelessWidget {
  const _ArcNavBackground();

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: const _ArcNavClipper(),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: CustomPaint(
          painter: const _ArcNavPainter(),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// A single free-floating tab. No shared bar background — this widget
/// carries its own glass backdrop. Every visual property (scale, rise,
/// tilt, opacity, how "expanded into a pill" it looks) is a pure function
/// of [distance] from the screen's center, recomputed every scroll frame.
class _GlassTab extends StatelessWidget {
  final double distance;
  final double scrollGloss;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final VoidCallback onTap;

  const _GlassTab({
    required this.distance,
    required this.scrollGloss,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Map distance -> a -90deg..+90deg sweep across `arcSpan` slots — the
    // "half circle" arc. Wider arcSpan than before means more neighboring
    // icons sit visibly on the curve instead of only the one right next
    // to center.
    final slots = (distance / ModernBottomNavBar.itemExtent)
        .clamp(-ModernBottomNavBar.arcSpan, ModernBottomNavBar.arcSpan);
    final angle = (slots / ModernBottomNavBar.arcSpan) * (math.pi / 2);
    final progress = math.sin(angle).abs(); // 0 at center, 1 at the edges

    final scale =
        lerpDouble(1.14, ModernBottomNavBar.minScale, progress) ?? 1.0;
    final riseFall =
        ModernBottomNavBar.curveHeight * (1 - math.cos(angle));
    // Raised floor (0.7, was 0.35) so off-center icons stay legible
    // instead of fading to near-invisible.
    final opacity = (1.0 - progress * 0.45).clamp(0.70, 1.0);
    final tilt = angle * 0.34;

    // How "centered" this tab is — drives the pill morphing into its
    // labeled, brighter, expanded glass state.
    final centeredness = (1 - (slots.abs() / 0.55)).clamp(0.0, 1.0);
    final pillWidth = lerpDouble(
      ModernBottomNavBar.collapsedWidth,
      ModernBottomNavBar.expandedWidth,
      centeredness,
    ) ??
        ModernBottomNavBar.collapsedWidth;
    final labelSlotWidth = (pillWidth - ModernBottomNavBar.collapsedWidth)
        .clamp(0.0, ModernBottomNavBar.expandedWidth - ModernBottomNavBar.collapsedWidth);
    final useActiveIcon = centeredness > 0.5;

    return SizedBox(
      width: ModernBottomNavBar.itemExtent,
      child: OverflowBox(
        minWidth: 0,
        maxWidth: ModernBottomNavBar.expandedWidth + 24,
        child: Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Opacity(
              opacity: opacity,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0016)
                  ..rotateY(tilt)
                  ..translate(0.0, riseFall)
                  ..scale(scale),
                // Each tab clips + blurs ONLY the pixels directly behind
                // itself — a small personal glass panel, not a shared bar.
                // Thicker glass: stronger blur, higher base opacity, and a
                // shadow that's present even when not centered so every
                // icon reads clearly over any page content.
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      height: 52,
                      width: pillWidth,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        color: Colors.black.withOpacity(
                          0.30 + 0.20 * centeredness,
                        ),
                        border: Border.all(
                          color: Colors.white
                              .withOpacity(0.30 + 0.30 * centeredness),
                          width: 1.1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(
                                0.22 + 0.14 * centeredness),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipRect(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                        children: [
                          _GlossyBubble(
                            centeredness: centeredness,
                            scrollGloss: scrollGloss,
                            icon: useActiveIcon ? activeIcon : icon,
                          ),
                          if (labelSlotWidth > 1)
                            SizedBox(
                              width: labelSlotWidth,
                              child: Opacity(
                                opacity: centeredness,
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                      right: 10),
                                  child: Text(
                                    label,
                                    maxLines: 1,
                                    softWrap: false,
                                    overflow: TextOverflow.clip,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The circular icon bubble — always carries its own translucent backdrop
/// (not just when centered), so the icon is legible against any page
/// content underneath. A gradient accent crossfades in as the tab centers,
/// plus a small specular glint that brightens while scrolling.
class _GlossyBubble extends StatelessWidget {
  final double centeredness; // 0..1
  final double scrollGloss; // 0..1
  final IconData icon;

  const _GlossyBubble({
    required this.centeredness,
    required this.scrollGloss,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    const size = ModernBottomNavBar.bubbleSize;
    return SizedBox(
      width: ModernBottomNavBar.collapsedWidth - 2.2,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Always-on translucent backdrop so the icon has contrast even
          // when this tab isn't centered.
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.16 + 0.10 * centeredness),
              border: Border.all(
                color: Colors.white.withOpacity(0.22 + 0.18 * centeredness),
                width: 1,
              ),
            ),
          ),
          // Crossfades in: the gradient accent for the centered tab.
          Opacity(
            opacity: centeredness,
            child: Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFBD91EF), Color(0xFFFFD49D)],
                ),
              ),
            ),
          ),
          Icon(
            icon,
            color: Colors.white,
            size: 22,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.55),
                blurRadius: 6,
              ),
            ],
          ),
          // Small specular glint — brightens while actively scrolling.
          Positioned(
            top: 5,
            left: 9,
            child: Container(
              width: size * 0.32,
              height: size * 0.16,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white.withOpacity(
                  (0.22 + 0.24 * centeredness + 0.18 * scrollGloss)
                      .clamp(0.0, 0.9),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// RUNNABLE EXAMPLE — delete in your real app, or keep to preview.
// ---------------------------------------------------------------------

void main() => runApp(const _DemoApp());

class _DemoApp extends StatelessWidget {
  const _DemoApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const _DemoScreen(),
    );
  }
}

class _DemoScreen extends StatefulWidget {
  const _DemoScreen();

  @override
  State<_DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<_DemoScreen> {
  int _currentIndex = 0;

  final List<(String, IconData, IconData, String)> _tabs = const [
    ('home', Icons.home_outlined, Icons.home, 'Home'),
    ('search', Icons.search, Icons.search, 'Search'),
    ('chat', Icons.chat_bubble_outline, Icons.chat_bubble, 'Chat'),
    ('cart', Icons.shopping_cart_outlined, Icons.shopping_cart, 'Cart'),
    ('orders', Icons.receipt_long_outlined, Icons.receipt_long, 'Orders'),
    ('wallet', Icons.account_balance_wallet_outlined,
    Icons.account_balance_wallet, 'Wallet'),
    ('offers', Icons.local_offer_outlined, Icons.local_offer, 'Offers'),
    ('wishlist', Icons.favorite_border, Icons.favorite, 'Wishlist'),
    ('notifications', Icons.notifications_none, Icons.notifications, 'Alerts'),
    ('profile', Icons.person_outline, Icons.person, 'Profile'),
    ('settings', Icons.settings_outlined, Icons.settings, 'Settings'),
    ('help', Icons.help_outline, Icons.help, 'Help'),
    ('analytics', Icons.bar_chart_outlined, Icons.bar_chart, 'Stats'),
    ('map', Icons.map_outlined, Icons.map, 'Map'),
    ('calendar', Icons.calendar_today_outlined, Icons.calendar_today,
    'Calendar'),
    ('more', Icons.more_horiz, Icons.more_horiz, 'More'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(title: Text(_tabs[_currentIndex].$4)),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3A1C71), Color(0xFFD76D77), Color(0xFFFFAF7B)],
          ),
        ),
        child: Center(
          child: Text(
            'Selected: ${_tabs[_currentIndex].$4}',
            style: const TextStyle(fontSize: 22, color: Colors.white),
          ),
        ),
      ),
      bottomNavigationBar: ModernBottomNavBar(
        currentIndex: _currentIndex,
        tabs: _tabs,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}