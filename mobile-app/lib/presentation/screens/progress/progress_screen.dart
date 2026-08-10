import 'package:flutter/material.dart';
import '../../../core/widgets/common_header.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  String _selectedPeriod = 'Monthly';

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF0F172A);
    final secondaryColor = const Color(0xFFEAB308);

    return Scaffold(
      appBar: const CommonHeader(title: 'Progress'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Card(
                    color: primaryColor,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text('Overall Progress', style: TextStyle(color: Colors.white, fontSize: 12)),
                          const SizedBox(height: 8),
                          Text('65%', style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    color: secondaryColor,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text('Rank', style: TextStyle(color: Colors.black, fontSize: 12)),
                          const SizedBox(height: 8),
                          Text('#12', style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: Colors.black, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Learning Progress', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: primaryColor)),
                    const SizedBox(height: 16),
                    _ProgressItem(title: 'Java Programming', progress: 0.85, color: Colors.blue),
                    const SizedBox(height: 12),
                    _ProgressItem(title: 'Data Structures', progress: 0.72, color: Colors.green),
                    const SizedBox(height: 12),
                    _ProgressItem(title: 'Database Management', progress: 0.60, color: Colors.orange),
                    const SizedBox(height: 12),
                    _ProgressItem(title: 'Web Development', progress: 0.90, color: Colors.purple),
                    const SizedBox(height: 12),
                    _ProgressItem(title: 'Software Engineering', progress: 0.55, color: Colors.red),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Weekly Activity', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: primaryColor)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _ActivityBar(day: 'Mon', hours: 4, color: Colors.blue)),
                        const SizedBox(width: 8),
                        Expanded(child: _ActivityBar(day: 'Tue', hours: 6, color: Colors.green)),
                        const SizedBox(width: 8),
                        Expanded(child: _ActivityBar(day: 'Wed', hours: 3, color: Colors.orange)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _ActivityBar(day: 'Thu', hours: 5, color: Colors.purple)),
                        const SizedBox(width: 8),
                        Expanded(child: _ActivityBar(day: 'Fri', hours: 7, color: Colors.red)),
                        const SizedBox(width: 8),
                        Expanded(child: _ActivityBar(day: 'Sat', hours: 2, color: Colors.blue)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Achievements', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: primaryColor)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(Icons.emoji_events, size: 40, color: secondaryColor),
                          const SizedBox(height: 8),
                          const Text('5 Badges', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(Icons.star, size: 40, color: Colors.orange),
                          const SizedBox(height: 8),
                          const Text('1200 Points', style: TextStyle(fontWeight: FontWeight.bold)),
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
    );
  }
}

class _ProgressItem extends StatelessWidget {
  final String title;
  final double progress;
  final Color color;
  const _ProgressItem({required this.title, required this.progress, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            Text('${(progress * 100).toInt()}%', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}

class _ActivityBar extends StatelessWidget {
  final String day;
  final int hours;
  final Color color;
  const _ActivityBar({required this.day, required this.hours, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$hours h', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Container(
          height: 80,
          width: double.infinity,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: hours / 8,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(day, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }
}