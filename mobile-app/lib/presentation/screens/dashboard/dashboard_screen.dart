import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/widgets/common_header.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF0F172A);
    final secondaryColor = const Color(0xFFEAB308);

    return Scaffold(
      appBar: CommonHeader(
        title: 'Dashboard',
        actions: [
          IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () => context.go(AppRoutes.notifications)),
          IconButton(icon: const Icon(Icons.person_outline), onPressed: () => context.go(AppRoutes.profile)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [primaryColor, primaryColor.withOpacity(0.8)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Welcome, Student!', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                Text('Java Full Stack Development', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
                const SizedBox(height: 12),
                Row(children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: secondaryColor, borderRadius: BorderRadius.circular(12)), child: const Text('Active', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 8),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(12)), child: const Text('60 days left', style: TextStyle(color: Colors.white, fontSize: 11))),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: _StatCard(title: 'Attendance', value: '92%', icon: Icons.check_circle, color: Colors.green, subtitle: 'This month')),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(title: 'Progress', value: '65%', icon: Icons.trending_up, color: secondaryColor, subtitle: 'Course')),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _StatCard(title: 'Performance', value: '78%', icon: Icons.star, color: Colors.blue, subtitle: 'Overall')),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(title: 'Streak', value: '5 days', icon: Icons.local_fire_department, color: Colors.orange, subtitle: 'Current')),
          ]),
          const SizedBox(height: 20),
          Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Performance Overview', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: primaryColor)),
            const SizedBox(height: 20),
            SizedBox(height: 180, child: CustomPaint(size: const Size(double.infinity, 180), painter: _PerformanceChartPainter())),
          ]))),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
              SizedBox(height: 100, child: CustomPaint(size: const Size(100, 100), painter: _PieChartPainter(segments: [
                _PieSegment(label: 'Completed', value: 0.65, color: secondaryColor),
                _PieSegment(label: 'In Progress', value: 0.20, color: Colors.blue),
                _PieSegment(label: 'Pending', value: 0.15, color: Colors.grey.shade300),
              ]))),
              const SizedBox(height: 8),
              Text('Course Progress', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ])))),
            const SizedBox(width: 12),
            Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
              SizedBox(height: 100, child: CustomPaint(size: const Size(100, 100), painter: _PieChartPainter(segments: [
                _PieSegment(label: 'Present', value: 0.92, color: Colors.green),
                _PieSegment(label: 'Absent', value: 0.08, color: Colors.red.shade300),
              ]))),
              const SizedBox(height: 8),
              Text('Attendance', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ])))),
          ]),
          const SizedBox(height: 20),
          Text('Quick Links', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: primaryColor)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _QuickLinkCard(title: 'Courses', icon: Icons.book, color: Colors.blue, onTap: () => context.go(AppRoutes.courses))),
            const SizedBox(width: 12),
            Expanded(child: _QuickLinkCard(title: 'Placements', icon: Icons.work, color: Colors.green, onTap: () => context.go(AppRoutes.placementDrives))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _QuickLinkCard(title: 'Calendar', icon: Icons.calendar_today, color: secondaryColor, onTap: () => context.go(AppRoutes.calendar))),
            const SizedBox(width: 12),
            Expanded(child: _QuickLinkCard(title: 'Bookmarks', icon: Icons.bookmark, color: Colors.purple, onTap: () => context.go(AppRoutes.bookmarks))),
          ]),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title; final String value; final IconData icon; final Color color; final String subtitle;
  const _StatCard({required this.title, required this.value, required this.icon, required this.color, required this.subtitle});
  @override Widget build(BuildContext context) {
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)), Icon(icon, color: color, size: 20)]),
      const SizedBox(height: 8),
      Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: color)),
      Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
    ])));
  }
}

class _QuickLinkCard extends StatelessWidget {
  final String title; final IconData icon; final Color color; final VoidCallback onTap;
  const _QuickLinkCard({required this.title, required this.icon, required this.color, required this.onTap});
  @override Widget build(BuildContext context) {
    return Card(child: InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap, child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [Icon(icon, color: color, size: 32), const SizedBox(height: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.w500))]))));
  }
}

class _PieSegment { final String label; final double value; final Color color; _PieSegment({required this.label, required this.value, required this.color}); }
class _PieChartPainter extends CustomPainter {
  final List<_PieSegment> segments;
  _PieChartPainter({required this.segments});
  @override void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    final paint = Paint()..style = PaintingStyle.fill;
    double startAngle = -pi / 2;
    for (final segment in segments) {
      final sweepAngle = 2 * pi * segment.value;
      paint.color = segment.color;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, true, paint);
      startAngle += sweepAngle;
    }
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PerformanceChartPainter extends CustomPainter {
  @override void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [const Color(0xFFEAB308).withOpacity(0.3), const Color(0xFFEAB308).withOpacity(0.0)]).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    final linePaint = Paint()..style = PaintingStyle.stroke..strokeWidth = 2.5..color = const Color(0xFFEAB308);
    final path = Path(); final linePath = Path();
    final points = [0.4, 0.55, 0.45, 0.7, 0.6, 0.75, 0.85, 0.72, 0.78];
    path.moveTo(0, size.height * (1 - points[0])); linePath.moveTo(0, size.height * (1 - points[0]));
    final stepX = size.width / (points.length - 1);
    for (int i = 1; i < points.length; i++) { final x = i * stepX; final y = size.height * (1 - points[i]); path.lineTo(x, y); linePath.lineTo(x, y); }
    path.lineTo(size.width, size.height); path.lineTo(0, size.height); path.close();
    canvas.drawPath(path, paint); canvas.drawPath(linePath, linePaint);
    final dotPaint = Paint()..color = const Color(0xFFEAB308)..style = PaintingStyle.fill;
    for (int i = 0; i < points.length; i++) { final x = i * stepX; final y = size.height * (1 - points[i]); canvas.drawCircle(Offset(x, y), 4, dotPaint); }
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}