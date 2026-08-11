import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/widgets/common_header.dart';

final notesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getNotes();
});

class NotesScreen extends ConsumerStatefulWidget {
  /// Optional lesson context: when opened from a lesson, new notes are linked
  /// to that lesson. When opened from the drawer/quick-links with no lesson
  /// in context, [lessonId] is 0 and notes are created as general notes.
  final int lessonId;
  const NotesScreen({super.key, required this.lessonId});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  Future<void> _openEditor(BuildContext context, {Map<String, dynamic>? note}) async {
    final titleController = TextEditingController(text: note?['title'] ?? '');
    final contentController = TextEditingController(text: note?['content'] ?? '');

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(note == null ? 'New Note' : 'Edit Note', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contentController,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'Note', border: OutlineInputBorder(), alignLabelWithHint: true),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A)),
                child: const Text('Save', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    final title = titleController.text.trim().isEmpty ? 'Untitled Note' : titleController.text.trim();
    final content = contentController.text.trim();
    final api = ref.read(apiServiceProvider);

    if (note == null) {
      await api.createNote(title: title, content: content, lessonId: widget.lessonId > 0 ? widget.lessonId : null);
    } else {
      await api.updateNote(note['id'] as int, title: title, content: content);
    }
    ref.invalidate(notesProvider);
  }

  Future<void> _deleteNote(Map<String, dynamic> note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Note'),
        content: Text('Delete "${note['title'] ?? 'this note'}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(apiServiceProvider).deleteNote(note['id'] as int);
    ref.invalidate(notesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesProvider);
    const secondaryColor = Color(0xFFEAB308);

    return Scaffold(
      appBar: const CommonHeader(showBackButton: true, title: 'Notes'),
      floatingActionButton: FloatingActionButton(
        backgroundColor: secondaryColor,
        onPressed: () => _openEditor(context),
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: notesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text('Failed to load notes', style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              TextButton(onPressed: () => ref.invalidate(notesProvider), child: const Text('Retry')),
            ],
          ),
        ),
        data: (notes) {
          if (notes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.note_alt_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('No notes yet', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('Tap + to add your first note', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
              final content = (note['content'] as String?) ?? '';
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(note['title'] ?? 'Untitled Note', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  onTap: () => _openEditor(context, note: note),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _deleteNote(note),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

