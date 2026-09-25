import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/data_providers.dart';

class LearningEntry {
  final int id;
  final String title, label, detail;
  final bool locked, completed;
  final double progress;
  final VoidCallback onOpen;
  const LearningEntry(
      {required this.id,
      required this.title,
      required this.label,
      required this.detail,
      required this.onOpen,
      this.locked = false,
      this.completed = false,
      this.progress = 0});
}

class LearningCollection extends ConsumerStatefulWidget {
  final String title, noun;
  final List<LearningEntry> entries;
  final VoidCallback onBack;
  final Future<void> Function() onRefresh;
  final Widget? footer;
  const LearningCollection(
      {super.key,
      required this.title,
      required this.noun,
      required this.entries,
      required this.onBack,
      required this.onRefresh,
      this.footer});
  @override
  ConsumerState<LearningCollection> createState() => _LearningCollectionState();
}

class _LearningCollectionState extends ConsumerState<LearningCollection> {
  String _filter = 'All';
  @override
  Widget build(BuildContext context) {
    final visible = widget.entries.where((entry) => switch (_filter) {
          'Completed' => entry.completed,
          'Available' => !entry.locked,
          'Locked' => entry.locked,
          _ => true,
        }).toList();
    final allCount = widget.entries.length;
    final availableCount = widget.entries.where((entry) => !entry.locked).length;
    final completedCount = widget.entries.where((entry) => entry.completed).length;
    final lockedCount = widget.entries.where((entry) => entry.locked).length;
    final tabs = <(String, IconData, Color, int)>[
      ('All', Icons.apps_rounded, const Color(0xFF9B5CFF), allCount),
      ('Available', Icons.lock_open_rounded, const Color(0xFF48AFFF), availableCount),
      ('Completed', Icons.check_circle_rounded, const Color(0xFF27D9D3), completedCount),
      ('Locked', Icons.lock_rounded, const Color(0xFFFFCF35), lockedCount),
    ];
    final isNavBarHidden = ref.watch(shellNavBarHiddenProvider);
    return ColoredBox(
      color: const Color(0xFF071D43),
      child: SafeArea(
        top: false,
        bottom: false,
        left: false,
        right: false,
        child: RefreshIndicator(
          onRefresh: widget.onRefresh,
          color: const Color(0xFFB66BFF),
          backgroundColor: const Color(0xFF123E72),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(12, 10, 12, isNavBarHidden ? 24 : 104),
            children: [
              Row(children: [
                InkWell(onTap: widget.onBack, customBorder: const CircleBorder(), child: const SizedBox(width: 42, height: 42, child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20))),
                const SizedBox(width: 7),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.noun, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text('Track your learning progress', style: TextStyle(color: Colors.white.withOpacity(.7), fontSize: 11))])),
                Container(width: 43, height: 43, decoration: BoxDecoration(color: const Color(0xFF9B5CFF), borderRadius: BorderRadius.circular(13), boxShadow: [BoxShadow(color: const Color(0xFF9B5CFF).withOpacity(.45), blurRadius: 15)]), child: Icon(widget.noun == 'Lessons' ? Icons.play_lesson_outlined : Icons.menu_book_rounded, color: Colors.white, size: 23)),
              ]),
              const SizedBox(height: 14),
              _LearningGlassPanel(padding: const EdgeInsets.all(6), child: Row(children: tabs.map((tab) {
                final active = _filter == tab.$1;
                return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: InkWell(onTap: () => setState(() => _filter = tab.$1), borderRadius: BorderRadius.circular(12), child: AnimatedContainer(duration: const Duration(milliseconds: 180), padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2), decoration: BoxDecoration(color: active ? const Color(0xFF8B4DFF) : Colors.white.withOpacity(.06), border: Border.all(color: active ? const Color(0xFFBDA0FF) : Colors.white12), borderRadius: BorderRadius.circular(12)), child: Column(children: [Icon(tab.$2, color: active ? Colors.white : tab.$3, size: 17), const SizedBox(height: 3), Text(tab.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: active ? Colors.white : Colors.white70, fontSize: 9, fontWeight: FontWeight.w600)), const SizedBox(height: 3), Text('${tab.$4}', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800))]))))); }).toList())),
              const SizedBox(height: 12),
              if (visible.isEmpty) _LearningGlassPanel(child: Padding(padding: const EdgeInsets.all(28), child: Text('No ${widget.noun.toLowerCase()} matching this filter', style: const TextStyle(color: Colors.white70, fontSize: 12)))) else ...visible.map((entry) => LearningCard(entry: entry, index: widget.entries.indexOf(entry))),
              if (widget.footer != null) widget.footer!,
            ],
          ),
        ),
      ),
    );
  }

  Widget _count(IconData icon, String label, bool dark) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
          color: dark ? const Color(0xFF001023) : Colors.white,
          borderRadius: BorderRadius.circular(32)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon,
            size: 22, color: dark ? Colors.white : const Color(0xFF128820)),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(
                color: dark ? Colors.white : Colors.black,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ]));
}

class _LearningGlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _LearningGlassPanel({required this.child, this.padding = const EdgeInsets.all(10)});
  @override
  Widget build(BuildContext context) => ClipRRect(borderRadius: BorderRadius.circular(15), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14), child: Container(padding: padding, decoration: BoxDecoration(color: const Color(0xFF123E72).withOpacity(.72), border: Border.all(color: const Color(0xFF4D9CD0).withOpacity(.55)), borderRadius: BorderRadius.circular(15)), child: child)));
}

class _LearningStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _LearningStat({required this.label, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [Container(width: 28, height: 28, decoration: BoxDecoration(color: color.withOpacity(.9), shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 16)), const SizedBox(height: 4), Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)), Text(label, style: const TextStyle(color: Colors.white70, fontSize: 8))]));
}

class LearningCard extends StatelessWidget {
  final LearningEntry entry;
  final int index;
  const LearningCard({super.key, required this.entry, required this.index});
  @override
  Widget build(BuildContext context) {
    final colors = [
      [const Color(0xFF123E72), const Color(0xFF0B2A58)],
      [const Color(0xFF164E78), const Color(0xFF0B3865)],
      [const Color(0xFF3C2C73), const Color(0xFF17285B)],
    ][index % 3];
    const foreground = Colors.white;
    return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Material(
            color: colors.first,
            borderRadius: BorderRadius.circular(28),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: ValueKey('learning-item-${entry.id}'),
              onTap: entry.onOpen,
              child: Ink(
                  decoration:
                      BoxDecoration(gradient: LinearGradient(colors: colors)),
                  child: Stack(children: [
                    Positioned(
                        right: -25,
                        bottom: -30,
                        child: IgnorePointer(
                            child: Icon(Icons.auto_awesome,
                                size: 190,
                                color: Colors.white.withValues(alpha: .06)))),
                    Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(
                                    child: Text(entry.label.toUpperCase(),
                                        style: TextStyle(
                                            color: foreground.withOpacity(.7),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600))),
                                Icon(
                                    entry.locked
                                        ? Icons.lock_outline
                                        : entry.completed
                                            ? Icons.check_circle_outline
                                            : Icons.menu_book_outlined,
                                    color: foreground,
                                    size: 22),
                              ]),
                              const SizedBox(height: 8),
                              Text(entry.title,
                                  style: TextStyle(
                                      color: foreground,
                                      fontSize: 21,
                                      height: 1.17,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 12),
                              Row(children: [
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(entry.detail,
                                          style: TextStyle(
                                              color: foreground, fontSize: 12)),
                                      const SizedBox(height: 8),
                                      ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          child: LinearProgressIndicator(
                                              value: entry.locked
                                                  ? 0
                                                  : entry.progress.clamp(0, 1),
                                              minHeight: 3,
                                              color: foreground,
                                              backgroundColor: foreground
                                                  .withValues(alpha: .18))),
                                    ])),
                                const SizedBox(width: 16),
                                Container(
                                    width: 52,
                                    height: 52,
                                    decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white),
                                    child: Icon(
                                        entry.locked
                                            ? Icons.lock_outline
                                            : Icons.arrow_forward,
                                        color: Colors.black,
                                                                                 size: 24)),
                              ]),
                            ])),
                  ])),
            )));
  }
}

/// Original local vector illustration, rather than the reference's 3-D asset.
class LearningArtwork extends CustomPainter {
  const LearningArtwork();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 160, size.height / 140);
    final paint = Paint();
    for (final (y, color) in [
      (96.0, const Color(0xFFFFBB05)),
      (64.0, const Color(0xFF05ADC2))
    ]) {
      final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(20, y, 125, 32), const Radius.circular(12));
      canvas.drawShadow(Path()..addRRect(rect), Colors.black38, 5, true);
      canvas.drawRRect(rect, paint..color = color);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(33, y + 6, 112, 20), const Radius.circular(7)),
          paint..color = const Color(0xFFFFFFEF));
      for (var i = 0; i < 3; i++) {
        canvas.drawLine(
            Offset(43, y + 11 + i * 4),
            Offset(139, y + 11 + i * 4),
            paint
              ..color = const Color(0xFFD9E2DD)
              ..strokeWidth = 1);
      }
    }
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(45, 26, 77, 40), const Radius.circular(8)),
        paint..color = const Color(0xFF171C20));
    final cap = Path()
      ..moveTo(8, 22)
      ..lineTo(83, 4)
      ..lineTo(154, 29)
      ..lineTo(82, 48)
      ..close();
    canvas.drawShadow(cap, Colors.black45, 5, true);
    canvas.drawPath(
        cap,
        paint
          ..shader = const LinearGradient(
                  colors: [Color(0xFF34383C), Color(0xFF03080C)])
              .createShader(const Rect.fromLTWH(8, 4, 146, 44)));
    paint.shader = null;
    canvas.drawLine(
        const Offset(83, 24),
        const Offset(141, 35),
        paint
          ..color = const Color(0xFFFFBF03)
          ..strokeWidth = 3);
    canvas.drawLine(const Offset(141, 35), const Offset(141, 73), paint);
    canvas.drawOval(const Rect.fromLTWH(136, 68, 10, 17), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant LearningArtwork oldDelegate) => false;
}
