import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/widgets/common_header.dart';

final leaderboardProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getWeeklyLeaderboard();
});

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  bool _showDashboard = true;

  static const _bgDark = Color(0xFF071D43);
  static const _cardDark = Color(0xFF0C2B64);
  static const _cyan = Color(0xFF27D9D3);
  static const _gold = Color(0xFFF59E0B);
  static const _purple = Color(0xFF9B5CFF);

  void _showPointsGuide(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF092350),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(Icons.stars_rounded, color: _gold, size: 24),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'How to Earn Leaderboard XP',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Climb weekly batch rankings by staying consistent with course activities:',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const Divider(color: Colors.white12, height: 24),
                _xpRule(
                  icon: Icons.assignment_turned_in_rounded,
                  iconColor: const Color(0xFFEC4899),
                  title: 'Submit Assignment',
                  desc: 'Earn full credit when submitted on time',
                  xp: '+50 XP',
                ),
                const SizedBox(height: 10),
                _xpRule(
                  icon: Icons.quiz_rounded,
                  iconColor: _purple,
                  title: 'Pass Exam / Quiz',
                  desc: 'Score above 70% in assessments',
                  xp: '+100 XP',
                ),
                const SizedBox(height: 10),
                _xpRule(
                  icon: Icons.fact_check_rounded,
                  iconColor: const Color(0xFF10B981),
                  title: 'Class & Daily Attendance',
                  desc: 'Checked-in daily before session start',
                  xp: '+20 XP',
                ),
                const SizedBox(height: 10),
                _xpRule(
                  icon: Icons.forum_rounded,
                  iconColor: _cyan,
                  title: 'Community Contribution',
                  desc: 'Answer fellow students in Q&A forum',
                  xp: '+30 XP',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _xpRule({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String desc,
    required String xp,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardDark.withOpacity(0.60),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _gold.withOpacity(0.20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _gold.withOpacity(0.40)),
            ),
            child: Text(
              xp,
              style: const TextStyle(
                color: _gold,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final leaderboardAsync = ref.watch(leaderboardProvider);

    return CommonHeaderScaffold(
      subtitle: 'Leaderboard',
      backgroundColor: _bgDark,
      body: SafeArea(
        top: false,
        bottom: false,
        left: false,
        right: false,
        child: Column(
          children: [
            // Top Bar: View Toggle and "How XP Works" Button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _ViewToggle(
                      showDashboard: _showDashboard,
                      onChanged: (value) =>
                          setState(() => _showDashboard = value),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: () => _showPointsGuide(context),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: _gold.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _gold.withOpacity(0.40)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.help_outline_rounded,
                              color: _gold, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'XP Guide',
                            style: TextStyle(
                              color: _gold,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: leaderboardAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator(color: _cyan)),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 48, color: Colors.white38),
                      const SizedBox(height: 12),
                      const Text('Failed to load leaderboard',
                          style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => ref.invalidate(leaderboardProvider),
                        child:
                            const Text('Retry', style: TextStyle(color: _cyan)),
                      ),
                    ],
                  ),
                ),
                data: (data) => _showDashboard
                    ? _PodiumDashboard(data: data)
                    : _LeaderboardList(data: data),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  final bool showDashboard;
  final ValueChanged<bool> onChanged;
  const _ViewToggle({required this.showDashboard, required this.onChanged});

  static const _cyan = Color(0xFF27D9D3);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF0A2656).withOpacity(0.80),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E5BB0).withOpacity(0.40)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _toggleButton(
              label: 'Podium',
              icon: Icons.emoji_events_rounded,
              selected: showDashboard,
              onTap: () => onChanged(true),
            ),
          ),
          Expanded(
            child: _toggleButton(
              label: 'All Ranks',
              icon: Icons.format_list_numbered_rounded,
              selected: !showDashboard,
              onTap: () => onChanged(false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleButton({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF14457B) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: selected
              ? Border.all(color: _cyan.withOpacity(0.60))
              : null,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? _cyan : Colors.white60,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 12.5,
                  color: selected ? Colors.white : Colors.white60,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PodiumDashboard extends ConsumerWidget {
  final Map<String, dynamic> data;
  const _PodiumDashboard({required this.data});

  static const _cardDark = Color(0xFF0C2B64);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = (data['entries'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final myRank = data['myRank'] as Map<String, dynamic>?;

    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.leaderboard_outlined,
                size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            const Text('No activity yet this week',
                style: TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 4),
            const Text(
              'Submit assignments, take exams & attend classes to rank up!',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final topThree = entries.take(3).toList();
    final rest =
        entries.length > 3 ? entries.sublist(3) : <Map<String, dynamic>>[];

    final isNavBarHidden = ref.watch(shellNavBarHiddenProvider);
    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, isNavBarHidden ? 28 : 110),
          children: [
            // Student Milestone & Standing Card
            if (myRank != null) ...[
              _StudentMilestoneCard(myRank: myRank, allEntries: entries),
              const SizedBox(height: 16),
            ],

            // Top-3 Podium
            if (topThree.isNotEmpty)
              Container(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
                decoration: BoxDecoration(
                  color: _cardDark.withOpacity(0.60),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                      color: const Color(0xFF1E5BB0).withOpacity(0.40)),
                ),
                child: _Podium(topThree: topThree),
              ),

            const SizedBox(height: 18),
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'Remaining Ranks',
                style: TextStyle(
                  color: Color(0xFF93C5FD),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ...rest.map((e) => _LeaderboardTile(
                  entry: e,
                  isCurrentUser: myRank != null &&
                      (e['studentId'] == myRank['studentId'] ||
                          e['name'] == myRank['name']),
                )),
          ],
        ),

        // Sticky Pinned bottom bar for current user's position
        if (myRank != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _PinnedPositionBar(myRank: myRank),
          ),
      ],
    );
  }
}

class _StudentMilestoneCard extends StatelessWidget {
  final Map<String, dynamic> myRank;
  final List<Map<String, dynamic>> allEntries;

  const _StudentMilestoneCard({
    required this.myRank,
    required this.allEntries,
  });

  static const _gold = Color(0xFFF59E0B);
  static const _cyan = Color(0xFF27D9D3);
  static const _green = Color(0xFF10B981);

  @override
  Widget build(BuildContext context) {
    final rank = (myRank['rank'] as num?)?.toInt() ?? 1;
    final score = (myRank['score'] as num?)?.toInt() ?? 0;

    // Calculate distance to next rank
    Map<String, dynamic>? nextStudent;
    if (rank > 1) {
      for (final e in allEntries) {
        if ((e['rank'] as num?)?.toInt() == rank - 1) {
          nextStudent = e;
          break;
        }
      }
    }

    final nextScore = (nextStudent?['score'] as num?)?.toInt() ?? (score + 30);
    final gap = (nextScore - score).clamp(0, 9999);
    final nextName = nextStudent?['name'] ?? 'next student';

    String tierLabel;
    Color tierColor;
    if (rank <= 3) {
      tierLabel = 'Diamond League 💎';
      tierColor = _cyan;
    } else if (rank <= 10) {
      tierLabel = 'Platinum Tier 👑';
      tierColor = _gold;
    } else {
      tierLabel = 'Rising Star 🚀';
      tierColor = _green;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0E3875), Color(0xFF144D9C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cyan.withOpacity(0.50)),
        boxShadow: [
          BoxShadow(
            color: _cyan.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _gold.withOpacity(0.25),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '#$rank',
                          style: const TextStyle(
                            color: _gold,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your Standing',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                            ),
                          ),
                          Text(
                            '$score Total XP',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: const TextStyle(
                              color: Color(0xFF93C5FD),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: tierColor.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tierColor.withOpacity(0.40)),
                ),
                child: Text(
                  tierLabel,
                  style: TextStyle(
                    color: tierColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Motivator bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  rank > 1 ? Icons.flash_on_rounded : Icons.emoji_events_rounded,
                  color: _gold,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    rank > 1
                        ? 'Only $gap XP needed to overtake # ${rank - 1} $nextName!'
                        : '🎉 You are currently leading the batch in 1st Place! Keep it up!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  final List<Map<String, dynamic>> topThree;
  const _Podium({required this.topThree});

  static Color _medalColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFF59E0B);
      case 2:
        return const Color(0xFF94A3B8);
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return Colors.white24;
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
    final first = topThree.isNotEmpty ? topThree[0] : null;
    final second = topThree.length > 1 ? topThree[1] : null;
    final third = topThree.length > 2 ? topThree[2] : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (second != null)
          Expanded(
            child: _PodiumPillar(
              entry: second,
              rank: 2,
              pillarHeight: 74,
              avatarRadius: 26,
              medalColor: _medalColor(2),
              initials: _initials(second['name'] ?? ''),
            ),
          ),
        if (first != null)
          Expanded(
            child: _PodiumPillar(
              entry: first,
              rank: 1,
              pillarHeight: 104,
              avatarRadius: 32,
              medalColor: _medalColor(1),
              initials: _initials(first['name'] ?? ''),
              isFirst: true,
            ),
          ),
        if (third != null)
          Expanded(
            child: _PodiumPillar(
              entry: third,
              rank: 3,
              pillarHeight: 58,
              avatarRadius: 24,
              medalColor: _medalColor(3),
              initials: _initials(third['name'] ?? ''),
            ),
          ),
      ],
    );
  }
}

class _PodiumPillar extends StatelessWidget {
  final Map<String, dynamic> entry;
  final int rank;
  final double pillarHeight;
  final double avatarRadius;
  final Color medalColor;
  final String initials;
  final bool isFirst;

  const _PodiumPillar({
    required this.entry,
    required this.rank,
    required this.pillarHeight,
    required this.avatarRadius,
    required this.medalColor,
    required this.initials,
    this.isFirst = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isFirst)
            const Text('👑', style: TextStyle(fontSize: 24))
          else
            const SizedBox(height: 14),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: medalColor, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: medalColor.withOpacity(0.40),
                  blurRadius: 10,
                ),
              ],
            ),
            padding: const EdgeInsets.all(2.5),
            child: CircleAvatar(
              radius: avatarRadius,
              backgroundColor: const Color(0xFF092350),
              child: Text(
                initials,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: avatarRadius * 0.6,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            entry['name'] ?? 'Student',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${entry['score']} pts',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: medalColor,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            height: pillarHeight,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  medalColor.withOpacity(0.85),
                  medalColor.withOpacity(0.35),
                ],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              border: Border.all(color: medalColor.withOpacity(0.60)),
            ),
            alignment: Alignment.center,
            child: Text(
              '$rank',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  final Map<String, dynamic> entry;
  final bool isCurrentUser;

  const _LeaderboardTile({
    required this.entry,
    this.isCurrentUser = false,
  });

  static const _cardDark = Color(0xFF0C2B64);
  static const _cyan = Color(0xFF27D9D3);

  @override
  Widget build(BuildContext context) {
    final rank = entry['rank'] ?? 0;
    final name = entry['name'] ?? 'Student';
    final score = entry['score'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? const Color(0xFF144D9C).withOpacity(0.70)
            : _cardDark.withOpacity(0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentUser
              ? _cyan
              : const Color(0xFF1E5BB0).withOpacity(0.40),
          width: isCurrentUser ? 1.5 : 1.0,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$rank',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isCurrentUser ? _cyan : Colors.white70,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry['assignmentsSubmitted'] ?? 0} assign • ${entry['examsSubmitted'] ?? 0} exams • ${entry['attendancePercent'] ?? 0}% att',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$score',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFFF59E0B),
                ),
              ),
              const Text(
                'XP',
                style: TextStyle(fontSize: 10, color: Colors.white54),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PinnedPositionBar extends StatelessWidget {
  final Map<String, dynamic> myRank;
  const _PinnedPositionBar({required this.myRank});

  static const _cyan = Color(0xFF27D9D3);
  static const _gold = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    final rank = myRank['rank'] ?? 0;
    final score = myRank['score'] ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF092350).withOpacity(0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cyan.withOpacity(0.60)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.50),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _gold.withOpacity(0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '#$rank',
              style: const TextStyle(
                color: _gold,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Your Active Position',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '$score XP',
            style: const TextStyle(
              color: _cyan,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardList extends StatelessWidget {
  final Map<String, dynamic> data;
  const _LeaderboardList({required this.data});

  @override
  Widget build(BuildContext context) {
    final entries = (data['entries'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final myRank = data['myRank'] as Map<String, dynamic>?;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final e = entries[index];
        return _LeaderboardTile(
          entry: e,
          isCurrentUser: myRank != null &&
              (e['studentId'] == myRank['studentId'] ||
                  e['name'] == myRank['name']),
        );
      },
    );
  }
}
