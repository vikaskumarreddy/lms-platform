import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/widgets/common_header.dart';

final leaderboardProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getWeeklyLeaderboard();
});

/// Lightweight weekly leaderboard: replaces the old static/fake Achievements
/// screen with a real, activity-driven weekly rank (assignments submitted +
/// attendance %), scoped to the student's own batch for a fair comparison.
class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(leaderboardProvider);
    const primaryColor = Color(0xFF0F172A);
    const secondaryColor = Color(0xFFEAB308);

    return Scaffold(
      appBar: const CommonHeader(title: 'Leaderboard'),
      body: leaderboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text('Failed to load leaderboard', style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              TextButton(onPressed: () => ref.invalidate(leaderboardProvider), child: const Text('Retry')),
            ],
          ),
        ),
        data: (data) => _LeaderboardBody(data: data, primaryColor: primaryColor, secondaryColor: secondaryColor),
      ),
    );
  }
}

class _LeaderboardBody extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color primaryColor;
  final Color secondaryColor;
  const _LeaderboardBody({required this.data, required this.primaryColor, required this.secondaryColor});

  @override
  Widget build(BuildContext context) {
    final entries = (data['entries'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final myRank = data['myRank'] as Map<String, dynamic>?;
    final weekStart = data['weekStart'] as String? ?? '';

    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.leaderboard_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No activity yet this week', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
            const SizedBox(height: 4),
            Text('Submit assignments, take exams & attend classes to rank up!', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [primaryColor, const Color(0xFF1E293B)]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.emoji_events, color: secondaryColor),
              const SizedBox(width: 8),
              const Text('This Week', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
            const SizedBox(height: 4),
            Text('Week of $weekStart', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            if (myRank != null) ...[
              const SizedBox(height: 12),
              Row(children: [
                CircleAvatar(radius: 18, backgroundColor: secondaryColor, child: Text('#${myRank['rank']}', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 12))),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Your rank: ${myRank['assignmentsSubmitted']} assignments · ${myRank['examsSubmitted']} exams · ${myRank['attendancePercent']}% attendance',
                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ]),
            ],
          ]),
        ),
        const SizedBox(height: 20),
        ...entries.map((e) => _LeaderboardRow(rank: e['rank'], entry: e)),
      ],
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> entry;
  const _LeaderboardRow({required this.rank, required this.entry});

  Color _medalColor() {
    switch (rank) {
      case 1: return const Color(0xFFEAB308);
      case 2: return const Color(0xFFB0BEC5);
      case 3: return const Color(0xFFCD7F32);
      default: return Colors.grey.shade300;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTopThree = rank <= 3;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: isTopThree ? BorderSide(color: _medalColor(), width: 1.5) : BorderSide.none,
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _medalColor().withOpacity(isTopThree ? 1 : 0.3),
          child: Text('$rank', style: TextStyle(fontWeight: FontWeight.bold, color: isTopThree ? Colors.white : Colors.grey.shade700)),
        ),
        title: Text(entry['name'] ?? 'Student', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${entry['assignmentsSubmitted']} assignments · ${entry['examsSubmitted']} exams · ${entry['attendancePercent']}% attendance',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${entry['score']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            Text('score', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}
