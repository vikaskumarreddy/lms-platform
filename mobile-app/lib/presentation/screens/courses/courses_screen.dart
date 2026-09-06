import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/subscription_provider.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/widgets/common_header.dart';
import '../../../core/utils/image_url.dart';
import '../../../data/models/course_model.dart';

class CoursesScreen extends ConsumerWidget {
  const CoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = ref.watch(subscriptionProvider);
    final activePlanIds = subscription.activePlanIds;
    final coursesAsync = ref.watch(coursesProvider);

    return Scaffold(
      appBar: const CommonHeader(title: 'My Courses'),
      body: coursesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text('Failed to load courses', style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(coursesProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (courses) {
          if (courses.isEmpty) {
            return const Center(child: Text('No courses available'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SubscriptionBanner(plan: subscription.plan),
              const SizedBox(height: 12),
              ...courses
                  .map((course) => _CourseCard(
                        course: course,
                        isLocked: !course.isAccessible(activePlanIds),
                      ))
                  .toList(),
            ],
          );
        },
      ),
    );
  }
}

class _SubscriptionBanner extends StatelessWidget {
  final SubscriptionPlan plan;

  const _SubscriptionBanner({required this.plan});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAB308).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEAB308).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium, color: Color(0xFFEAB308), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${plan.label} Plan',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          TextButton(
            onPressed: () => context.go('/subscription'),
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final CourseModel course;
  final bool isLocked;

  const _CourseCard({required this.course, required this.isLocked});

  void _open(BuildContext context) {
    if (isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upgrade your subscription to access this course')),
      );
      return;
    }
    context.push('/courses/${course.id}');
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor(course.id);
    final hasImage = course.thumbnailUrl.isNotEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isLocked
            ? () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Upgrade your subscription to unlock this course')),
                );
              }
            : () => context.go('/courses/${course.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isLocked
                    ? Icon(Icons.lock, color: color.withOpacity(0.4), size: 28)
                    : Icon(Icons.menu_book, color: color, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isLocked ? Colors.grey.shade500 : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      course.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isLocked ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: isLocked ? 0.0 : (course.progress ?? 0),
                        minHeight: 4,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isLocked
                          ? 'Locked • Upgrade to access'
                          : course.totalLessons == 0
                              ? 'No lessons yet'
                              : '${course.lessonsDisplay} lessons • ${course.progressPercent}%',
                      style: TextStyle(
                        fontSize: 11,
                        color: isLocked ? const Color(0xFFEAB308) : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isLocked ? Icons.lock_outline : Icons.chevron_right,
                color: isLocked ? const Color(0xFFEAB308) : const Color(0xFFEAB308),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getColor(int id) {
    const colors = [
      Color(0xFF0F172A),
      Color(0xFFEAB308),
      Colors.green,
      Color(0xFF3B82F6),
      Color(0xFF8B5CF6),
      Color(0xFFF97316),
    ];
    return colors[id % colors.length];
  }
}

extension on CourseModel {
  bool isAccessible(Set<int>? activePlanIds) {
    if (planId == null) return true;
    if (activePlanIds == null) return false;
    return activePlanIds.contains(planId);
  }
}