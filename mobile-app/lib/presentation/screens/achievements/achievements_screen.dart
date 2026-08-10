import 'package:flutter/material.dart';
import '../../../core/widgets/common_header.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});
  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  String _selectedTab = 'Badges';

  final List<_AchievementBadge> _badges = [
    _AchievementBadge(
      title: 'First Steps',
      description: 'Completed your first lesson',
      icon: Icons.directions_walk,
      color: Colors.green,
      isUnlocked: true,
      unlockedDate: '12 Jul 2026',
    ),
    _AchievementBadge(
      title: 'Quick Learner',
      description: 'Completed 5 lessons in a week',
      icon: Icons.bolt,
      color: Colors.orange,
      isUnlocked: true,
      unlockedDate: '15 Jul 2026',
    ),
    _AchievementBadge(
      title: 'Streak Master',
      description: 'Maintained a 7-day learning streak',
      icon: Icons.local_fire_department,
      color: Colors.red,
      isUnlocked: true,
      unlockedDate: '18 Jul 2026',
    ),
    _AchievementBadge(
      title: 'Quiz Champion',
      description: 'Scored 90%+ in a quiz',
      icon: Icons.emoji_events,
      color: const Color(0xFFEAB308),
      isUnlocked: true,
      unlockedDate: '20 Jul 2026',
    ),
    _AchievementBadge(
      title: 'Assignment Pro',
      description: 'Submitted 5 assignments on time',
      icon: Icons.assignment_turned_in,
      color: Colors.blue,
      isUnlocked: true,
      unlockedDate: '22 Jul 2026',
    ),
    _AchievementBadge(
      title: 'Code Warrior',
      description: 'Solved 25 coding problems',
      icon: Icons.code,
      color: Colors.purple,
      isUnlocked: false,
      unlockedDate: null,
    ),
    _AchievementBadge(
      title: 'Placement Ready',
      description: 'Completed all mock interviews',
      icon: Icons.work,
      color: Colors.teal,
      isUnlocked: false,
      unlockedDate: null,
    ),
    _AchievementBadge(
      title: 'Perfect Attendance',
      description: 'Attended 30 consecutive classes',
      icon: Icons.check_circle,
      color: Colors.indigo,
      isUnlocked: false,
      unlockedDate: null,
    ),
    _AchievementBadge(
      title: 'Course Completer',
      description: 'Completed an entire course',
      icon: Icons.military_tech,
      color: Colors.pink,
      isUnlocked: false,
      unlockedDate: null,
    ),
  ];

  final List<_Milestone> _milestones = [
    _Milestone(title: 'Lessons Completed', current: 32, target: 100, unit: 'lessons'),
    _Milestone(title: 'Coding Problems Solved', current: 18, target: 50, unit: 'problems'),
    _Milestone(title: 'Quiz Score Average', current: 78, target: 90, unit: '%'),
    _Milestone(title: 'Attendance', current: 92, target: 95, unit: '%'),
    _Milestone(title: 'Assignments Submitted', current: 6, target: 10, unit: 'assignments'),
    _Milestone(title: 'Mock Interviews', current: 2, target: 5, unit: 'interviews'),
  ];

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF0F172A);
    final secondaryColor = const Color(0xFFEAB308);

    final unlockedCount = _badges.where((b) => b.isUnlocked).length;

    return Scaffold(
      appBar: const CommonHeader(title: 'Achievements'),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, primaryColor.withOpacity(0.85)],
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('My Achievements', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('$unlockedCount of ${_badges.length} badges unlocked', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: unlockedCount / _badges.length,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  color: secondaryColor,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Text('${(unlockedCount / _badges.length * 100).toStringAsFixed(0)}% complete',
                  style: TextStyle(color: Colors.white70, fontSize: 11)),
            ]),
          ),
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              _buildTab('Badges', _badges.length),
              _buildTab('Milestones', _milestones.length),
            ]),
          ),
          Expanded(
            child: _selectedTab == 'Badges'
                ? _buildBadgesGrid()
                : _buildMilestonesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int count) {
    final isSelected = _selectedTab == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEAB308) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.black : Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.black.withOpacity(0.15) : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$count', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSelected ? Colors.black : Colors.grey.shade600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadgesGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: _badges.length,
      itemBuilder: (context, index) => _BadgeCard(badge: _badges[index]),
    );
  }

  Widget _buildMilestonesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _milestones.length,
      itemBuilder: (context, index) => _MilestoneCard(milestone: _milestones[index]),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final _AchievementBadge badge;
  const _BadgeCard({required this.badge});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: badge.isUnlocked ? Colors.white : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: badge.isUnlocked ? badge.color.withOpacity(0.3) : Colors.grey.shade200,
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: badge.isUnlocked ? badge.color.withOpacity(0.15) : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Icon(
              badge.icon,
              color: badge.isUnlocked ? badge.color : Colors.grey.shade400,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              badge.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: badge.isUnlocked ? const Color(0xFF0F172A) : Colors.grey.shade500,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              badge.isUnlocked && badge.unlockedDate != null ? 'Earned ${badge.unlockedDate}' : 'Locked',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                color: badge.isUnlocked ? badge.color : Colors.grey.shade400,
                fontWeight: badge.isUnlocked ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  final _Milestone milestone;
  const _MilestoneCard({required this.milestone});

  @override
  Widget build(BuildContext context) {
    final progress = (milestone.current / milestone.target).clamp(0.0, 1.0);
    final isCompleted = milestone.current >= milestone.target;
    final secondaryColor = const Color(0xFFEAB308);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(milestone.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            ),
            if (isCompleted)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Completed', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
              )
            else
              Text('${milestone.current}/${milestone.target} ${milestone.unit}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade200,
              color: isCompleted ? Colors.green : secondaryColor,
              minHeight: 8,
            ),
          ),
        ]),
      ),
    );
  }
}

class _AchievementBadge {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isUnlocked;
  final String? unlockedDate;

  _AchievementBadge({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.isUnlocked,
    required this.unlockedDate,
  });
}

class _Milestone {
  final String title;
  final double current;
  final double target;
  final String unit;

  _Milestone({
    required this.title,
    required this.current,
    required this.target,
    required this.unit,
  });
}