import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/widgets/common_header.dart';
import '../../../data/models/lesson.dart';
import 'learning_collection.dart';

final learningLessonsProvider = FutureProvider.autoDispose
    .family<List<Lesson>, int>(
        (ref, id) => ref.watch(apiServiceProvider).getModuleLessons(id));

class CourseSectionLessonsScreen extends ConsumerWidget {
  final int sectionId;
  const CourseSectionLessonsScreen({super.key, required this.sectionId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courseId = GoRouterState.of(context).pathParameters['id'];
    return CommonHeaderScaffold(
      subtitle: 'Lessons',
      showBackButton: true,
      onBack: () => context.go(courseId == null ? '/courses' : '/courses/$courseId'),
      backgroundColor: const Color(0xFF071D43),
      body: ref.watch(learningLessonsProvider(sectionId)).when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFF27D9D3))),
            error: (_, __) => Center(
                child: TextButton(
                    onPressed: () =>
                        ref.invalidate(learningLessonsProvider(sectionId)),
                    child: const Text('Failed to load lessons. Retry',
                        style: TextStyle(color: Color(0xFF27D9D3))))),
            data: (lessons) => LearningCollection(
              title: 'My\nlessons',
              noun: 'Lessons',
              onBack: () {
                final courseId = GoRouterState.of(context).pathParameters['id'];
                context
                    .go(courseId == null ? '/courses' : '/courses/$courseId');
              },
              onRefresh: () async {
                ref.invalidate(learningLessonsProvider(sectionId));
                await ref.read(learningLessonsProvider(sectionId).future);
              },
              entries: lessons
                  .map((lesson) => LearningEntry(
                        id: lesson.id,
                        title: lesson.title,
                        label: lesson.isMandatory
                            ? 'Required lesson'
                            : 'Optional lesson',
                        locked: lesson.isLocked,
                        completed: lesson.completed,
                        progress: lesson.completed ? 1 : 0,
                        detail: lesson.isLocked
                            ? 'Locked · Upgrade to access'
                            : '${lesson.duration} · ${lesson.completed ? 'Completed' : 'Not completed'}',
                        onOpen: () async {
                          if (lesson.isLocked) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Upgrade your subscription to unlock this lesson')));
                          } else {
                            await context.push('/lesson/${lesson.id}');
                            if (context.mounted) {
                              ref.invalidate(
                                  learningLessonsProvider(sectionId));
                            }
                          }
                        },
                      ))
                  .toList(),
            ),
          ));
  }
}
