import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/widgets/common_header.dart';

final notesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getNotes();
});

const List<Color> _kNoteColors = [
  Color(0xFFFEF3C7), // amber
  Color(0xFFDCFCE7), // green
  Color(0xFFE0F2FE), // sky
  Color(0xFFFCE7F3), // pink
  Color(0xFFEDE9FE), // violet
  Color(0xFFFFE4E6), // rose
];

Color _colorForNote(dynamic id) {
  final i = (id is int ? id : 0).abs() % _kNoteColors.length;
  return _kNoteColors[i];
}

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
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _NoteEditorScreen(note: note, lessonId: widget.lessonId > 0 ? widget.lessonId : null)),
    );
    if (result != true) return;
    ref.invalidate(notesProvider);
  }

  Future<void> _deleteNote(Map<String, dynamic> note) async {
    await ref.read(apiServiceProvider).deleteNote(note['id'] as int);
    ref.invalidate(notesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesProvider);
    const secondaryColor = Color(0xFFEAB308);
    const primaryColor = Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: const CommonHeader(showBackButton: true, title: 'My Notes'),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryColor,
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Note', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: secondaryColor.withOpacity(0.12), shape: BoxShape.circle),
                    child: const Icon(Icons.sticky_note_2_outlined, size: 56, color: secondaryColor),
                  ),
                  const SizedBox(height: 20),
                  Text('No notes yet', style: TextStyle(color: Colors.grey.shade700, fontSize: 17, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Tap "New Note" to capture your first idea', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                ],
              ),
            );
          }
          return MasonryNotesGrid(
            notes: notes,
            onTap: (note) => _openEditor(context, note: note),
            onDelete: _deleteNote,
          );
        },
      ),
    );
  }
}

/// A staggered, Keep-style grid of colored note cards with a modern
/// swipe-free delete affordance (tap the trash chip) instead of the old
/// plain red delete icon.
class MasonryNotesGrid extends StatelessWidget {
  final List<Map<String, dynamic>> notes;
  final ValueChanged<Map<String, dynamic>> onTap;
  final ValueChanged<Map<String, dynamic>> onDelete;
  const MasonryNotesGrid({super.key, required this.notes, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        final content = (note['content'] as String?) ?? '';
        return _NoteCard(
          title: note['title'] ?? 'Untitled Note',
          content: content,
          color: _colorForNote(note['id']),
          onTap: () => onTap(note),
          onDelete: () => onDelete(note),
        );
      },
    );
  }
}

class _NoteCard extends StatelessWidget {
  final String title;
  final String content;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _NoteCard({required this.title, required this.content, required this.color, required this.onTap, required this.onDelete});

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete note?'),
        content: Text('"$title" will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade50, foregroundColor: Colors.red.shade700),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) onDelete();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _confirmDelete(context),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.06), shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF475569)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                content.isEmpty ? 'No content' : content,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: const Color(0xFF334155).withOpacity(content.isEmpty ? 0.4 : 0.85), height: 1.4),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Full-screen distraction-free note editor, replacing the old cramped
/// bottom-sheet form with a proper modern writing surface.
class _NoteEditorScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? note;
  final int? lessonId;
  const _NoteEditorScreen({this.note, this.lessonId});

  @override
  ConsumerState<_NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<_NoteEditorScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?['title'] ?? '');
    _contentController = TextEditingController(text: widget.note?['content'] ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final title = _titleController.text.trim().isEmpty ? 'Untitled Note' : _titleController.text.trim();
    final content = _contentController.text.trim();
    final api = ref.read(apiServiceProvider);

    if (widget.note == null) {
      await api.createNote(title: title, content: content, lessonId: widget.lessonId);
    } else {
      await api.updateNote(widget.note!['id'] as int, title: title, content: content);
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFFFFBEB);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        foregroundColor: const Color(0xFF0F172A),
        actions: [
          _saving
              ? const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
              : IconButton(icon: const Icon(Icons.check_circle_rounded, size: 28, color: Color(0xFFEAB308)), onPressed: _save, tooltip: 'Save'),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            controller: _titleController,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            decoration: const InputDecoration(hintText: 'Title', border: InputBorder.none),
          ),
          const Divider(height: 24),
          Expanded(
            child: TextField(
              controller: _contentController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(fontSize: 16, height: 1.5, color: Color(0xFF334155)),
              decoration: const InputDecoration(hintText: 'Start writing...', border: InputBorder.none),
            ),
          ),
        ]),
      ),
    );
  }
}
