import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/providers/org_theme_provider.dart';
import 'notes_workspace.dart';
import 'study_topics.dart';

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
  Future<void> _openEditor(BuildContext context,
      {Map<String, dynamic>? note, int? lessonId, int? topicId}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _NoteEditorScreen(
          note: note,
          lessonId: lessonId,
          topicId: topicId,
        ),
      ),
    );
    if (result != true) return;
    ref.invalidate(notesProvider);
  }

  Future<void> _deleteNote(Map<String, dynamic> note) async {
    final deleted =
        await ref.read(apiServiceProvider).deleteNote(note['id'] as int);
    if (!mounted) return;
    if (deleted) {
      ref.invalidate(notesProvider);
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(deleted
            ? 'Note deleted.'
            : 'Could not delete note. Please try again.')));
  }

  @override
  Widget build(BuildContext context) {
    return NotesWorkspace(
      notes: ref.watch(notesProvider),
      lessonId: widget.lessonId,
      onEdit: (note, lessonId, [topicId]) =>
          _openEditor(context, note: note, lessonId: lessonId, topicId: topicId),
      onDelete: _deleteNote,
      onRefresh: () async {
        ref.invalidate(notesProvider);
        await ref.read(notesProvider.future);
      },
    );
  }
}

/// Full-screen note editor styled in dark navy glass theme, featuring
/// topic mapping (select existing topic or create a new topic on the fly).
class _NoteEditorScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? note;
  final int? lessonId;
  final int? topicId;
  const _NoteEditorScreen({this.note, this.lessonId, this.topicId});

  @override
  ConsumerState<_NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<_NoteEditorScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  int? _selectedTopicId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?['title'] ?? '');
    _contentController =
        TextEditingController(text: widget.note?['content'] ?? '');
    if (widget.note != null && widget.note!['topicId'] != null) {
      _selectedTopicId = int.tryParse('${widget.note!['topicId']}');
    } else {
      _selectedTopicId = widget.topicId;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _createNewTopicDialog() async {
    final titleController = TextEditingController();
    final createdTopic = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0C2758),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.15)),
        ),
        title: const Text('Create New Topic',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter a title for your study topic. Notes can be mapped to this topic for quick organization.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('topic-title'),
              controller: titleController,
              autofocus: true,
              cursorColor: const Color(0xFF27D9D3),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Topic Title',
                labelStyle: const TextStyle(color: Colors.white70),
                hintText: 'e.g. Flutter State, Data Structures',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: const Color(0xFF104476).withOpacity(0.60),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF27D9D3), width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF9B5CFF),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final text = titleController.text.trim();
              if (text.isEmpty) return;
              try {
                final topic =
                    await ref.read(apiServiceProvider).createStudyTopic(text);
                ref.invalidate(studyTopicsProvider);
                if (ctx.mounted) Navigator.pop(ctx, topic);
              } catch (_) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text('Could not create topic. Try again.')),
                  );
                }
              }
            },
            child: const Text('Save topic'),
          ),
        ],
      ),
    );

    if (createdTopic != null && createdTopic['id'] != null) {
      setState(() {
        _selectedTopicId = (createdTopic['id'] as num).toInt();
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final title = _titleController.text.trim().isEmpty
        ? 'Untitled Note'
        : _titleController.text.trim();
    final content = _contentController.text.trim();
    final api = ref.read(apiServiceProvider);

    final saved = widget.note == null
        ? await api.createNote(
                title: title,
                content: content,
                lessonId: widget.lessonId,
                topicId: _selectedTopicId) !=
            null
        : await api.updateNote(
            widget.note!['id'] as int,
            title: title,
            content: content,
            topicId: _selectedTopicId,
          );

    if (!mounted) return;
    if (saved) {
      Navigator.pop(context, true);
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not save note. Please try again.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(orgThemeProvider);
    final topics = ref.watch(studyTopicsProvider).valueOrNull ?? [];
    const bg = Color(0xFF071D43);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.note == null ? 'New Note' : 'Edit Note',
          style: const TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF9B5CFF),
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.check_circle_rounded,
                  size: 28, color: theme.accent),
              onPressed: _save,
              tooltip: 'Save',
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        left: false,
        right: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF104476).withOpacity(0.40),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: TextField(
                  controller: _titleController,
                  cursorColor: const Color(0xFF27D9D3),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Note Title',
                    hintStyle: TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.transparent,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Topic Mapping Bar: Select existing topic or create a new topic
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF104476).withOpacity(0.55),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sell_outlined,
                        size: 18, color: Color(0xFF9B5CFF)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          value: _selectedTopicId,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF0C2758),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded,
                              color: Colors.white70),
                          hint: const Text('No Topic (General)',
                              style: TextStyle(color: Colors.white60, fontSize: 13.5)),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('No Topic (General)',
                                  style: TextStyle(color: Colors.white60)),
                            ),
                            ...topics.map((t) {
                              final id = (t['id'] as num).toInt();
                              return DropdownMenuItem<int?>(
                                value: id,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF27D9D3),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        '${t['title']}',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            setState(() => _selectedTopicId = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _createNewTopicDialog,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF9B5CFF).withOpacity(0.25),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFF9B5CFF).withOpacity(0.5)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, size: 14, color: Color(0xFFBD91EF)),
                            SizedBox(width: 4),
                            Text(
                              'New Topic',
                              style: TextStyle(
                                  color: Color(0xFFBD91EF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF104476).withOpacity(0.30),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _contentController,
                    maxLines: null,
                    expands: true,
                    cursorColor: const Color(0xFF27D9D3),
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(
                      fontSize: 15.5,
                      height: 1.6,
                      color: Colors.white,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Start writing your notes...',
                      hintStyle: TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
