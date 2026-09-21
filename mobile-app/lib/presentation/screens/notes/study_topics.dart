import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/data_providers.dart';

// Invalidate when accounts change, and discard data after leaving the workspace.
final studyTopicsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  ref.watch(mobileAuthProvider.select((state) => state.user?.id));
  return ref.watch(apiServiceProvider).getStudyTopics();
});

class StudyTopicDialog extends ConsumerStatefulWidget {
  const StudyTopicDialog({super.key});

  @override
  ConsumerState<StudyTopicDialog> createState() => _StudyTopicDialogState();
}

class _StudyTopicDialogState extends ConsumerState<StudyTopicDialog> {
  final _title = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_title.text.trim().isEmpty || _title.text.trim().length > 200) {
      setState(() => _error = 'Enter a topic title (1–200 characters).');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(apiServiceProvider).createStudyTopic(_title.text);
      if (!mounted) return;
      ref.invalidate(studyTopicsProvider);
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save topic. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_saving,
        child: AlertDialog(
          backgroundColor: const Color(0xFF0C2758),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withOpacity(0.15)),
          ),
          title: const Text('Create topic',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                key: const ValueKey('topic-title'),
                controller: _title,
                autofocus: true,
                enabled: !_saving,
                maxLength: 200,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    labelText: 'Topic title',
                    labelStyle: TextStyle(color: Colors.white70)),
                onSubmitted: (_) => _save()),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!,
                    style: const TextStyle(color: Color(0xFFFF6B6B))),
              ),
          ]),
          actions: [
            TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Colors.white60))),
            FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF9B5CFF)),
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save topic')),
          ],
        ),
      );
}

class StudyTopicsList extends ConsumerWidget {
  final String query;
  final bool alphabetical;
  const StudyTopicsList(
      {super.key, required this.query, required this.alphabetical});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> refresh() async {
      ref.invalidate(studyTopicsProvider);
      await ref.read(studyTopicsProvider.future);
    }

    return ref.watch(studyTopicsProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Could not load topics'),
            TextButton(
                onPressed: () => ref.invalidate(studyTopicsProvider),
                child: const Text('Retry')),
          ])),
          data: (source) {
            final topics = source
                .where((t) => '${t['title']}'
                    .toLowerCase()
                    .contains(query.trim().toLowerCase()))
                .toList();
            if (alphabetical) {
              topics.sort((a, b) => '${a['title']}'
                  .toLowerCase()
                  .compareTo('${b['title']}'.toLowerCase()));
            }
            return RefreshIndicator(
                onRefresh: refresh,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
                  itemCount: topics.isEmpty ? 1 : topics.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, index) {
                    if (topics.isEmpty) {
                      return Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(query.trim().isEmpty
                              ? 'No topics yet. Tap + to create your first topic.'
                              : 'No matching topics'));
                    }
                    final topic = topics[index];
                    return Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                            color: const Color(0xFFF3EFFF),
                            borderRadius: BorderRadius.circular(23)),
                        child: Row(children: [
                          const Icon(Icons.menu_book_outlined,
                              color: Color(0xFF8052B6)),
                          const SizedBox(width: 16),
                          Expanded(
                              child: Text('${topic['title']}',
                                  style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600))),
                        ]));
                  },
                ));
          },
        );
  }
}
