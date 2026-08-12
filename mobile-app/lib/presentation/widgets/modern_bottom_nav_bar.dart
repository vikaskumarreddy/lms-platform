import 'package:flutter/material.dart';

/// A modern bottom navigation bar inspired by Instagram/Amazon-style tab
/// bars: the selected tab's icon floats up inside a filled circular "bubble"
/// that visually pokes above the bar, with a smooth animated transition
/// between tabs, replacing the old plain [BottomNavigationBar].
class ModernBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final List<(String, IconData, IconData, String)> tabs;
  final ValueChanged<int> onTap;

  const ModernBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.tabs,
    required this.onTap,
  });

  static const Color _primary = Color(0xFF0F172A);
  static const Color _accent = Color(0xFFEAB308);

  @override
  Widget build(BuildContext context) {
    const barHeight = 64.0;
    const bubbleSize = 52.0;

    return SizedBox(
      height: barHeight + 16,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Base bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: barHeight,
              decoration: BoxDecoration(
                color: _primary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: const Border(top: BorderSide(color: _accent, width: 2.5)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 16, offset: const Offset(0, -4)),
                ],
              ),
              child: Row(
                children: List.generate(tabs.length, (index) {
                  final isSelected = index == currentIndex;
                  final tab = tabs[index];
                  return Expanded(
                    child: InkWell(
                      onTap: () => onTap(index),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: isSelected ? 0 : 1,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(tab.$2, color: Colors.white70, size: 24),
                            const SizedBox(height: 3),
                            Text(tab.$4, style: const TextStyle(fontSize: 10.5, color: Colors.white70, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          // Animated floating bubble for the selected tab
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            left: _bubbleLeft(context, bubbleSize),
            bottom: barHeight - bubbleSize / 2 - 6,
            width: _tabWidth(context),
            child: Center(
              child: GestureDetector(
                onTap: () => onTap(currentIndex),
                child: Container(
                  width: bubbleSize,
                  height: bubbleSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _accent,
                    boxShadow: [
                      BoxShadow(color: _accent.withOpacity(0.5), blurRadius: 14, offset: const Offset(0, 4)),
                    ],
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: Icon(tabs[currentIndex].$3, color: _primary, size: 26),
                ),
              ),
            ),
          ),
          // Label under the bubble
          Positioned(
            left: _bubbleLeft(context, bubbleSize),
            bottom: 2,
            width: _tabWidth(context),
            child: Center(
              child: Text(
                tabs[currentIndex].$4,
                style: const TextStyle(fontSize: 10.5, color: _accent, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _tabWidth(BuildContext context) => MediaQuery.of(context).size.width / tabs.length;

  double _bubbleLeft(BuildContext context, double bubbleSize) {
    final tabWidth = _tabWidth(context);
    return tabWidth * currentIndex;
  }
}
