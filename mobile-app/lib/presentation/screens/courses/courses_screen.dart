import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/subscription_provider.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/widgets/common_header.dart';
import 'learning_collection.dart';

class CoursesScreen extends ConsumerWidget {
  const CoursesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = ref.watch(subscriptionProvider);
    return CommonHeaderScaffold(
        subtitle: 'Courses',
        backgroundColor: const Color(0xFF071D43),
        body: ref.watch(coursesProvider).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(
                  child: TextButton(
                      onPressed: () => ref.invalidate(coursesProvider),
                      child: const Text('Failed to load courses. Retry'))),
              data: (courses) => LearningCollection(
                title: 'My\nlearning',
                noun: 'Courses',
                onBack: () => context.go('/home'),
                onRefresh: () async {
                  ref.invalidate(coursesProvider);
                  await ref.read(coursesProvider.future);
                },
                footer: TextButton(
                    onPressed: () => context.go('/subscription'),
                    child: Text('${subscription.plan.label} Plan · Upgrade')),
                entries: courses.map((course) {
                  final hasPlanAccess = course.planId == null ||
                      subscription.activePlanIds.contains(course.planId) ||
                      subscription.plan.canAccessCourse(course.id);
                  final locked = !hasPlanAccess;
                  final progress = course.progress ??
                      (course.totalLessons > 0
                          ? course.completedLessons / course.totalLessons
                          : 0.0);
                  return LearningEntry(
                      id: course.id,
                      title: course.title,
                      label: 'Course',
                      locked: locked,
                      completed: progress >= 1,
                      progress: progress,
                      detail: locked
                          ? 'Locked · Upgrade to access'
                          : '${course.lessonsDisplay} lessons · ${(progress * 100).round()}%',
                      onOpen: () {
                        if (locked) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text(
                                  'Upgrade your subscription to unlock this course')));
                        } else {
                          context.go('/courses/${course.id}');
                        }
                      });
                }).toList(),
              ),
            ));
  }
}
