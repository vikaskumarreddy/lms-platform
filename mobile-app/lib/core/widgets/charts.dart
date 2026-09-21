import 'dart:ui';
import 'package:flutter/material.dart';

/// Small, dependency-free chart primitives (pure [CustomPainter], no chart
/// package) used on the Home and Placements screens. Every color is passed in
/// by the caller from the org's live theme — nothing here is hardcoded.

/// A circular percentage ring (like the "Attendance"/"Progress" rings in the
/// reference dashboard), with the percentage centered inside.
class RingProgress extends StatelessWidget {
  final double percent; // 0-100
  final Color color;
  final Color track;
  final Color textColor;
  final double size;
  final double strokeWidth;
  const RingProgress({
    super.key,
    required this.percent,
    required this.color,
    required this.track,
    required this.textColor,
    this.size = 56,
    this.strokeWidth = 7,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
                percent: percent,
                color: color,
                track: track,
                strokeWidth: strokeWidth),
          ),
          Text('${percent.round()}%',
              style: TextStyle(
                  fontSize: size * 0.24,
                  fontWeight: FontWeight.bold,
                  color: textColor)),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double percent;
  final Color color;
  final Color track;
  final double strokeWidth;
  _RingPainter(
      {required this.percent,
      required this.color,
      required this.track,
      required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final fgPaint = Paint()
      ..shader = SweepGradient(colors: [color.withOpacity(0.55), color])
          .createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);
    final sweep = 2 * 3.141592653589793 * (percent.clamp(0, 100) / 100);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        -3.141592653589793 / 2, sweep, false, fgPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.percent != percent ||
      oldDelegate.color != color ||
      oldDelegate.track != track;
}

/// A smooth mini line/area chart (like the "Top Contributor" trend chart in
/// the reference dashboard): a curved line over a set of 0..1 normalized
/// values with a soft gradient fill beneath it.
class MiniLineChart extends StatelessWidget {
  final List<double> values; // each 0..1
  final Color lineColor;
  final Color fillColor;
  final double height;
  const MiniLineChart(
      {super.key,
      required this.values,
      required this.lineColor,
      required this.fillColor,
      this.height = 90});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: CustomPaint(
          painter: _LineChartPainter(
              values: values, lineColor: lineColor, fillColor: fillColor)),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> values;
  final Color lineColor;
  final Color fillColor;
  _LineChartPainter(
      {required this.values, required this.lineColor, required this.fillColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final points = <Offset>[];
    final stepX =
        values.length > 1 ? size.width / (values.length - 1) : size.width;
    for (var i = 0; i < values.length; i++) {
      final x = stepX * i;
      final y = size.height - (values[i].clamp(0.0, 1.0) * size.height);
      points.add(Offset(x, y));
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [fillColor.withOpacity(0.45), fillColor.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);
    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);
    canvas.drawCircle(points.last, 4.5, Paint()..color = lineColor);
    canvas.drawCircle(
        points.last,
        4.5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) => true;
}

/// A stacked donut chart (like the "Open/Applied/Selected" breakdown), with
/// segments supplied as (value, color) pairs.
class DonutChart extends StatelessWidget {
  final List<(double, Color)> segments;
  final Color track;
  final double size;
  final double strokeWidth;
  final Widget? center;
  const DonutChart(
      {super.key,
      required this.segments,
      required this.track,
      this.size = 120,
      this.strokeWidth = 16,
      this.center});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
              size: Size(size, size),
              painter: _DonutPainter(
                  segments: segments, track: track, strokeWidth: strokeWidth)),
          if (center != null) center!,
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<(double, Color)> segments;
  final Color track;
  final double strokeWidth;
  _DonutPainter(
      {required this.segments, required this.track, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final total = segments.fold<double>(0, (sum, s) => sum + s.$1);
    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = track
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth);
    if (total <= 0) return;
    var start = -3.141592653589793 / 2;
    for (final seg in segments) {
      final sweep = 2 * 3.141592653589793 * (seg.$1 / total);
      final paint = Paint()
        ..color = seg.$2
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => true;
}

/// A reusable frosted "glossy" card: blurred translucent surface over the
/// [baseColor] passed in (usually the org theme's surface/primary color),
/// with a soft highlight border and shadow — the base visual language for
/// every card on the redesigned Home/Placements screens.
class GlossyCard extends StatelessWidget {
  final Widget child;
  final Color baseColor;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final double blur;
  final double opacity;
  const GlossyCard({
    super.key,
    required this.child,
    required this.baseColor,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.blur = 18,
    this.opacity = 0.72,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: baseColor.withOpacity(opacity),
            borderRadius: borderRadius,
            border: Border.all(color: Colors.white.withOpacity(0.16), width: 1),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 22,
                  offset: const Offset(0, 10)),
              BoxShadow(
                  color: Colors.white.withOpacity(0.06),
                  blurRadius: 1,
                  offset: const Offset(0, 1)),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
