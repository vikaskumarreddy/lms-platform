import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/providers/subscription_provider.dart';
import '../../../core/widgets/common_header.dart';
import '../../../data/models/course_section.dart';
import 'learning_collection.dart';

final learningModulesProvider = FutureProvider.autoDispose
    .family<List<CourseSection>, int>(
        (ref, id) => ref.watch(apiServiceProvider).getCourseSections(id));

class CourseDetailScreen extends ConsumerWidget {
  final int id;
  const CourseDetailScreen({super.key, required this.id});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = ref.watch(subscriptionProvider);
    return CommonHeaderScaffold(
      subtitle: 'Modules',
      body: ref.watch(learningModulesProvider(id)).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(
                child: TextButton(
                    onPressed: () =>
                        ref.invalidate(learningModulesProvider(id)),
                    child: const Text('Failed to load modules. Retry'))),
            data: (sections) => LearningCollection(
              title: 'My\nmodules',
              noun: 'Modules',
              onBack: () => context.go('/courses'),
              onRefresh: () async {
                ref.invalidate(learningModulesProvider(id));
                await ref.read(learningModulesProvider(id).future);
              },
              entries: sections.map((section) {
                final progress = section.totalLessons > 0
                    ? section.completedLessons / section.totalLessons
                    : 0.0;
                // The course list already filters entitlement. Do not treat the
                // mere presence of any active plan as access to every course.
                // Module-level locks remain authoritative for this course.
                final locked = section.isLocked;
                return LearningEntry(
                    id: section.id,
                    title: section.title,
                    label: 'Module',
                    locked: locked,
                    completed: progress >= 1,
                    progress: progress,
                    detail: locked
                        ? 'Locked · Upgrade to access'
                        : '${section.completedLessons}/${section.totalLessons} lessons · ${(progress * 100).round()}%',
                    onOpen: () {
                      if (locked) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text(
                                'Upgrade your subscription to unlock this section')));
                      } else {
                        context.go('/courses/$id/sections/${section.id}');
                      }
                    });
              }).toList(),
            ),
          ));
  }
}
