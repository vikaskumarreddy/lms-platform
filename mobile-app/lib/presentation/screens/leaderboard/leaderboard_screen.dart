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
///
/// Offers two views over the same data: a podium-style "Dashboard" (default)
/// and the original vertical "List" view, preserved unchanged.
class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  bool _showDashboard = true;

  @override
  Widget build(BuildContext context) {
    final leaderboardAsync = ref.watch(leaderboardProvider);
    const primaryColor = Color(0xFF0F172A);
    const secondaryColor = Color(0xFFEAB308);

    return Scaffold(
      appBar: const CommonHeader(title: 'Leaderboard'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _ViewToggle(
              showDashboard: _showDashboard,
              primaryColor: primaryColor,
              onChanged: (value) => setState(() => _showDashboard = value),
            ),
          ),
          Expanded(
            child: leaderboardAsync.when(
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
              data: (data) => _showDashboard
                  ? _PodiumDashboard(data: data, primaryColor: primaryColor, secondaryColor: secondaryColor)
                  : _LeaderboardBody(data: data, primaryColor: primaryColor, secondaryColor: secondaryColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  final bool showDashboard;
  final Color primaryColor;
  final ValueChanged<bool> onChanged;
  const _ViewToggle({required this.showDashboard, required this.primaryColor, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: _ToggleButton(label: 'Dashboard', selected: showDashboard, primaryColor: primaryColor, onTap: () => onChanged(true))),
          Expanded(child: _ToggleButton(label: 'List', selected: !showDashboard, primaryColor: primaryColor, onTap: () => onChanged(false))),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color primaryColor;
  final VoidCallback onTap;
  const _ToggleButton({required this.label, required this.selected, required this.primaryColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 1))] : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: selected ? primaryColor : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}

/// Podium-style dashboard: crown + top-3 avatars, numbered podium blocks,
/// a ranked list for #4+, and a sticky "Your Position" bar pinned to the
/// bottom of the screen when the student has a rank this week.
class _PodiumDashboard extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color primaryColor;
  final Color secondaryColor;
  const _PodiumDashboard({required this.data, required this.primaryColor, required this.secondaryColor});

  @override
  Widget build(BuildContext context) {
    final entries = (data['entries'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final myRank = data['myRank'] as Map<String, dynamic>?;

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

    final topThree = entries.take(3).toList();
    final rest = entries.length > 3 ? entries.sublist(3) : <Map<String, dynamic>>[];

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            children: [
              if (topThree.isNotEmpty) _Podium(topThree: topThree),
              const SizedBox(height: 20),
              ...rest.map((e) => _LeaderboardRow(rank: e['rank'], entry: e)),
              if (myRank != null) const SizedBox(height: 80),
            ],
          ),
        ),
        if (myRank != null) _YourPositionBar(myRank: myRank, primaryColor: primaryColor, secondaryColor: secondaryColor),
      ],
    );
  }
}

class _Podium extends StatelessWidget {
  final List<Map<String, dynamic>> topThree;
  const _Podium({required this.topThree});

  Color _medalColor(int rank) {
    switch (rank) {
      case 1: return const Color(0xFFEAB308);
      case 2: return const Color(0xFFB0BEC5);
      case 3: return const Color(0xFFCD7F32);
      default: return Colors.grey.shade300;
    }
  }

  String _initials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    // Classic podium arrangement: 2nd (left), 1st (center, tallest), 3rd (right).
    final first = topThree.isNotEmpty ? topThree[0] : null;
    final second = topThree.length > 1 ? topThree[1] : null;
    final third = topThree.length > 2 ? topThree[2] : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (second != null) Expanded(child: _PodiumTile(entry: second, blockHeight: 64, avatarRadius: 26, medalColor: _medalColor(2), initials: _initials(second['name'] ?? ''))),
        if (first != null) Expanded(child: _PodiumTile(entry: first, blockHeight: 88, avatarRadius: 34, medalColor: _medalColor(1), initials: _initials(first['name'] ?? ''), isFirst: true)),
        if (third != null) Expanded(child: _PodiumTile(entry: third, blockHeight: 52, avatarRadius: 24, medalColor: _medalColor(3), initials: _initials(third['name'] ?? ''))),
      ],
    );
  }
}

class _PodiumTile extends StatelessWidget {
  final Map<String, dynamic> entry;
  final double blockHeight;
  final double avatarRadius;
  final Color medalColor;
  final String initials;
  final bool isFirst;
  const _PodiumTile({
    required this.entry,
    required this.blockHeight,
    required this.avatarRadius,
    required this.medalColor,
    required this.initials,
    this.isFirst = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isFirst) const Text('👑', style: TextStyle(fontSize: 26)),
          if (isFirst) const SizedBox(height: 2),
          CircleAvatar(
            radius: avatarRadius,
            backgroundColor: medalColor,
            child: Text(
              initials,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: avatarRadius * 0.55),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            entry['name'] ?? 'Student',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 2),
          Text('${entry['score']} pts', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            height: blockHeight,
            decoration: BoxDecoration(
              color: medalColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            alignment: Alignment.center,
            child: Text(
              '${entry['rank']}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _YourPositionBar extends StatelessWidget {
  final Map<String, dynamic> myRank;
  final Color primaryColor;
  final Color secondaryColor;
  const _YourPositionBar({required this.myRank, required this.primaryColor, required this.secondaryColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: secondaryColor,
            child: Text('#${myRank['rank']}', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 11)),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Your Position', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500)),
          ),
          Text('${myRank['score']} pts', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
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
