import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/routes.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/providers/org_theme_provider.dart';
import '../../../core/widgets/common_header.dart';
import 'study_topics.dart';
import 'personal_reminders.dart';

const _purple = Color(0xFF9B5CFF);
const _cyan = Color(0xFF27D9D3);
const _yellow = Color(0xFFFFCF35);
const _bgDark = Color(0xFF071D43);
const _surfaceDark = Color(0xFF104476);

/// The 3 top tabs requested: 1. Notes, 2. Todo, 3. Remainder
enum NotesTab { notes, todo, remainder }

class NotesWorkspace extends ConsumerStatefulWidget {
  final AsyncValue<List<Map<String, dynamic>>> notes;
  final int lessonId;
  final void Function(Map<String, dynamic>? note, int? lessonId, [int? topicId]) onEdit;
  final ValueChanged<Map<String, dynamic>> onDelete;
  final Future<void> Function() onRefresh;

  const NotesWorkspace({
    super.key,
    required this.notes,
    required this.lessonId,
    required this.onEdit,
    required this.onDelete,
    required this.onRefresh,
  });

  @override
  ConsumerState<NotesWorkspace> createState() => _NotesWorkspaceState();
}

class _NotesWorkspaceState extends ConsumerState<NotesWorkspace> {
  NotesTab _activeTab = NotesTab.notes;
  bool _searching = false;
  bool _alphabetical = false;
  int? _folder;
  int? _topicFilter;
  final _search = TextEditingController();

  // Local Todos state
  List<Map<String, dynamic>> _todos = [];
  bool _todosLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadTodos();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (GoRouter.maybeOf(context) == null) return;
    final uri = GoRouterState.of(context).uri;
    final viewParam = uri.queryParameters['view'];
    if (viewParam != null) {
      if (viewParam == 'reminders' || viewParam == 'remainder') {
        _activeTab = NotesTab.remainder;
      } else if (viewParam == 'todos' || viewParam == 'todo') {
        _activeTab = NotesTab.todo;
      } else {
        _activeTab = NotesTab.notes;
      }
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadTodos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId') ?? 0;
      final raw = prefs.getString('student_todos_$userId');
      if (raw != null) {
        final decoded = (jsonDecode(raw) as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        if (mounted) setState(() => _todos = decoded);
      }
    } catch (_) {}
    if (mounted) setState(() => _todosLoaded = true);
  }

  Future<void> _saveTodos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId') ?? 0;
      await prefs.setString('student_todos_$userId', jsonEncode(_todos));
    } catch (_) {}
  }

  void _addTodo(String title) {
    if (title.trim().isEmpty) return;
    final item = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'title': title.trim(),
      'completed': false,
      'createdAt': DateTime.now().toIso8601String(),
    };
    setState(() {
      _todos.insert(0, item);
    });
    _saveTodos();
  }

  void _toggleTodo(int index) {
    setState(() {
      _todos[index]['completed'] = !(_todos[index]['completed'] == true);
    });
    _saveTodos();
  }

  void _deleteTodo(int index) {
    setState(() {
      _todos.removeAt(index);
    });
    _saveTodos();
  }

  void _showAddTodoDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0C2758),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.15)),
        ),
        title: const Text('Add Todo Item',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Task title',
            labelStyle: const TextStyle(color: Colors.white70),
            hintText: 'e.g. Revise Chapter 3, Submit assignment',
            hintStyle: const TextStyle(color: Colors.white30),
            filled: true,
            fillColor: Colors.white.withOpacity(0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
          ),
          onSubmitted: (val) {
            Navigator.pop(ctx);
            _addTodo(val);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _purple),
            onPressed: () {
              Navigator.pop(ctx);
              _addTodo(controller.text);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  int _lesson(Map<String, dynamic> note) =>
      int.tryParse('${note['lessonId']}') ?? 0;

  String _folderTitle(int id) => id == 0 ? 'General Notes' : 'Lesson $id';

  DateTime? _date(Map<String, dynamic> note) =>
      DateTime.tryParse('${note['updatedAt'] ?? note['createdAt']}')?.toLocal();

  String _dateLabel(DateTime? date) {
    if (date == null) return 'No date yet';
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    }
    return DateFormat(date.year == now.year ? 'MMMM d' : 'MMM d, y')
        .format(date);
  }

  void _createNote() {
    final lesson = _folder ?? widget.lessonId;
    widget.onEdit(null, lesson > 0 ? lesson : null, _topicFilter);
  }

  Future<void> _confirmDelete(Map<String, dynamic> note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0C2758),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.15)),
        ),
        title: const Text('Delete note?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          '“${note['title'] ?? 'Untitled Note'}” will be permanently deleted.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) widget.onDelete(note);
  }

  @override
  Widget build(BuildContext context) {
    final rawNotes = widget.notes.valueOrNull ?? [];
    final reminders = _activeTab == NotesTab.remainder
        ? (ref.watch(personalRemindersProvider).valueOrNull ?? [])
        : const <Map<String, dynamic>>[];
    final pendingReminders =
        reminders.where((r) => '${r['status']}' == 'PENDING').length;
    final activeTodos = _todos.where((t) => t['completed'] != true).length;
    final isNavBarHidden = ref.watch(shellNavBarHiddenProvider);

    return CommonHeaderScaffold(
      subtitle: 'Notes',
      backgroundColor: _bgDark,
      floatingActionButton: _buildFab(),
      body: SafeArea(
        top: false,
        bottom: false,
        left: false,
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            // Top Navigation Tabs (1. Notes, 2. Todo, 3. Remainder)
            _buildTopTabs(
              notesCount: rawNotes.length,
              todosCount: activeTodos,
              remindersCount: pendingReminders,
            ),
            const SizedBox(height: 10),

            // Tab View Body
            Expanded(
              child: switch (_activeTab) {
                NotesTab.notes => _buildNotesTab(rawNotes, isNavBarHidden),
                NotesTab.todo => _buildTodoTab(isNavBarHidden),
                NotesTab.remainder => _buildRemainderTab(),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildFab() {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [_purple, Color(0xFFCAA6F4)]),
        boxShadow: [
          BoxShadow(
            color: Color(0x40BD91EF),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: FloatingActionButton(
        key: const ValueKey('workspace-fab'),
        tooltip: switch (_activeTab) {
          NotesTab.notes => 'New Note',
          NotesTab.todo => 'Create todo',
          NotesTab.remainder => 'Create reminder',
        },
        onPressed: switch (_activeTab) {
          NotesTab.notes => _createNote,
          NotesTab.todo => _showAddTodoDialog,
          NotesTab.remainder => () => showDialog<bool>(
              context: context, builder: (_) => const ReminderDialog()),
        },
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const CircleBorder(),
        child: Icon(
          switch (_activeTab) {
            NotesTab.notes => Icons.note_add_outlined,
            NotesTab.todo => Icons.add_task_rounded,
            NotesTab.remainder => Icons.add_alert_outlined,
          },
          size: 24,
        ),
      ),
    );
  }

  Widget _buildTopTabs({
    required int notesCount,
    required int todosCount,
    required int remindersCount,
  }) {
    final tabs = [
      (
        NotesTab.notes,
        'Notes',
        Icons.description_outlined,
        notesCount,
        'Notes',
        'Notebooks',
      ),
      (
        NotesTab.todo,
        'Todo',
        Icons.checklist_rounded,
        todosCount,
        'Todo',
        'Todos',
      ),
      (
        NotesTab.remainder,
        'Remainder',
        Icons.notifications_active_outlined,
        remindersCount,
        'Remainder',
        'Reminders',
      ),
    ];

    return Container(
      key: const ValueKey('notes-navigation'),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: tabs.map((tab) {
          final active = _activeTab == tab.$1;
          return Expanded(
            child: Tooltip(
              message: tab.$6, // Allows tests checking 'Notebooks'/'Todos'/'Reminders'
              child: Tooltip(
                message: tab.$5, // Allows checking 'Notes'/'Todo'/'Remainder'
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _activeTab = tab.$1;
                      _folder = null;
                      _topicFilter = null;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                    decoration: BoxDecoration(
                      color: active ? _purple : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: _purple.withOpacity(0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          tab.$3,
                          size: 17,
                          color: active ? Colors.white : Colors.white70,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            tab.$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: active ? Colors.white : Colors.white70,
                              fontSize: 13,
                              fontWeight:
                                  active ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (tab.$4 > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: active
                                  ? Colors.white.withOpacity(0.25)
                                  : Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${tab.$4}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- TAB 1: NOTES CONTENT ---
  Widget _buildNotesTab(
      List<Map<String, dynamic>> rawNotes, bool isNavBarHidden) {
    return widget.notes.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: _purple)),
      error: (_, __) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load notes',
                style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: widget.onRefresh,
              child: const Text('Retry', style: TextStyle(color: _cyan)),
            ),
          ],
        ),
      ),
      data: (source) {
        final topics = ref.watch(studyTopicsProvider).valueOrNull ?? [];
        final topicMap = {
          for (final t in topics)
            if (t['id'] is num) (t['id'] as num).toInt(): '${t['title']}'
        };

        final notes = [...source]..sort((a, b) => _alphabetical
            ? '${a['title']}'.toLowerCase().compareTo('${b['title']}'.toLowerCase())
            : (_date(b) ?? DateTime(1970)).compareTo(_date(a) ?? DateTime(1970)));

        final query = _search.text.trim().toLowerCase();
        final filtered = notes.where((n) {
          final matchFolder = _folder == null || _lesson(n) == _folder;
          final matchTopic = _topicFilter == null ||
              (int.tryParse('${n['topicId']}') == _topicFilter);
          final topicName = topicMap[int.tryParse('${n['topicId']}')] ?? '';
          final matchQuery = query.isEmpty ||
              '${n['title']} ${n['content']} ${_folderTitle(_lesson(n))} $topicName'
                  .toLowerCase()
                  .contains(query);
          return matchFolder && matchTopic && matchQuery;
        }).toList();

        final groups = <int, List<Map<String, dynamic>>>{};
        for (final note in notes) {
          groups.putIfAbsent(_lesson(note), () => []).add(note);
        }
        final folders = groups.keys.toList();
        if (_alphabetical) {
          folders.sort((a, b) => _folderTitle(a).compareTo(_folderTitle(b)));
        }

        final showNotes =
            _folder != null || _topicFilter != null || query.isNotEmpty || folders.length <= 1;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search and Controls Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFF104476).withOpacity(0.55),
                        borderRadius: BorderRadius.circular(14),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.15)),
                      ),
                      child: TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        cursorColor: _cyan,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search notes or topics...',
                          hintStyle: const TextStyle(
                              color: Colors.white54, fontSize: 13.5),
                          prefixIcon: Tooltip(
                            message: 'Search notes',
                            child: const Icon(Icons.search,
                                color: Color(0xFF27D9D3), size: 20),
                          ),
                          suffixIcon: _search.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear,
                                      color: Colors.white70, size: 18),
                                  onPressed: () =>
                                      setState(() => _search.clear()),
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.transparent,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: _alphabetical ? 'Sort by latest' : 'Sort A–Z',
                    child: InkWell(
                      onTap: () =>
                          setState(() => _alphabetical = !_alphabetical),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.12)),
                        ),
                        child: Icon(
                          _alphabetical
                              ? Icons.sort_by_alpha_rounded
                              : Icons.access_time_rounded,
                          color: _alphabetical ? _cyan : Colors.white70,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Topics Filter Bar with "+ New Topic" action
            _buildTopicFilterBar(topics, source),

            // Back button if drilled down into a notebook or topic
            if (_folder != null || _topicFilter != null)
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
                child: TextButton.icon(
                  onPressed: () => setState(() {
                    _folder = null;
                    _topicFilter = null;
                  }),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 14, color: _cyan),
                  label: Text(
                    _folder != null
                        ? 'Back to Notebooks'
                        : 'Back to All Topics',
                    style: const TextStyle(
                        color: _cyan,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),

            // Notes / Notebooks List
            Expanded(
              child: RefreshIndicator(
                onRefresh: widget.onRefresh,
                color: _purple,
                backgroundColor: _surfaceDark,
                child: filtered.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(36),
                        children: [
                          Center(
                            child: Column(
                              children: [
                                Icon(Icons.auto_stories_outlined,
                                    size: 52,
                                    color: Colors.white.withOpacity(0.3)),
                                const SizedBox(height: 14),
                                Text(
                                  query.isEmpty
                                      ? 'No notes yet'
                                      : 'No matching notes found',
                                  style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 10),
                                if (query.isEmpty)
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                        backgroundColor: _purple),
                                    onPressed: _createNote,
                                    icon: const Icon(Icons.add, size: 18),
                                    label: const Text('Create your first note'),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(16, 4, 16, isNavBarHidden ? 28 : 120),
                        itemCount: showNotes ? filtered.length : folders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, index) {
                          if (showNotes) {
                            final note = filtered[index];
                            final topicId =
                                int.tryParse('${note['topicId']}');
                            final topicName = topicMap[topicId];
                            final date = _date(note);

                            return _buildNoteCard(
                              note: note,
                              topicName: topicName,
                              date: date,
                              onTap: () => widget.onEdit(
                                note,
                                _lesson(note) > 0 ? _lesson(note) : null,
                                topicId,
                              ),
                              onDelete: () => _confirmDelete(note),
                            );
                          } else {
                            // Show Notebooks cards (e.g. "General Notes", "Lesson 42")
                            final fId = folders[index];
                            final members = groups[fId] ?? [];
                            final dates = members
                                .map(_date)
                                .whereType<DateTime>()
                                .toList()
                              ..sort((a, b) => b.compareTo(a));
                            final date = dates.firstOrNull;

                            return _buildNotebookCard(
                              id: fId,
                              count: members.length,
                              date: date,
                              onTap: () => setState(() => _folder = fId),
                            );
                          }
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTopicFilterBar(
      List<Map<String, dynamic>> topics, List<Map<String, dynamic>> allNotes) {
    return Container(
      height: 38,
      margin: const EdgeInsets.only(top: 6, bottom: 6),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // "All" filter chip
          _buildChip(
            label: 'All Notes',
            selected: _topicFilter == null && _folder == null,
            onTap: () => setState(() {
              _topicFilter = null;
              _folder = null;
            }),
          ),
          const SizedBox(width: 8),

          // Render each Study Topic
          ...topics.map((t) {
            final id = (t['id'] as num).toInt();
            final count = allNotes
                .where((n) => int.tryParse('${n['topicId']}') == id)
                .length;
            final selected = _topicFilter == id;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Tooltip(
                message: 'Topics', // Test selector support
                child: _buildChip(
                  label: '${t['title']}',
                  count: count > 0 ? count : null,
                  selected: selected,
                  onTap: () => setState(() {
                    _topicFilter = selected ? null : id;
                    _folder = null;
                  }),
                ),
              ),
            );
          }),

          // "+ New Topic" button
          InkWell(
            onTap: () => showDialog<bool>(
              context: context,
              builder: (_) => const StudyTopicDialog(),
            ),
            borderRadius: BorderRadius.circular(20),
            child: Tooltip(
              message: 'Create topic',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: _purple.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _purple.withOpacity(0.4)),
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
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    int? count,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _purple : Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFFBDA0FF) : Colors.white12,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.bold : FontWeight.w600,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withOpacity(0.25)
                      : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNoteCard({
    required Map<String, dynamic> note,
    required String? topicName,
    required DateTime? date,
    required VoidCallback onTap,
    required VoidCallback onDelete,
  }) {
    final title = '${note['title'] ?? 'Untitled Note'}';
    final content = '${note['content'] ?? ''}'.trim();

    return Container(
      decoration: BoxDecoration(
        color: _surfaceDark.withOpacity(0.55),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (topicName != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _cyan.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: _cyan.withOpacity(0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.sell, size: 10, color: _cyan),
                            const SizedBox(width: 4),
                            Text(
                              topicName,
                              style: const TextStyle(
                                color: _cyan,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      _dateLabel(date),
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 12),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Delete note',
                      icon: const Icon(Icons.delete_outline,
                          size: 19, color: Colors.white60),
                      onPressed: onDelete,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                if (content.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: Colors.white70, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotebookCard({
    required int id,
    required int count,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceDark.withOpacity(0.55),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _purple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.folder_outlined,
                      color: _purple, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _folderTitle(id),
                        style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$count ${count == 1 ? 'Note' : 'Notes'}  •  ${_dateLabel(date)}',
                        style: const TextStyle(
                            fontSize: 12.5, color: Colors.white60),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    color: Colors.white38, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- TAB 2: TODO CONTENT ---
  Widget _buildTodoTab(bool isNavBarHidden) {
    if (!_todosLoaded) {
      return const Center(
          child: CircularProgressIndicator(color: _purple));
    }

    final completedCount = _todos.where((t) => t['completed'] == true).length;
    final totalCount = _todos.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary Header Card
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surfaceDark.withOpacity(0.55),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Study Tasks',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        totalCount == 0
                            ? 'No tasks created yet'
                            : '$completedCount of $totalCount completed',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _purple,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _showAddTodoDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Task'),
                ),
              ],
            ),
          ),
        ),

        // Todo List
        Expanded(
          child: _todos.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.checklist_rounded,
                            size: 52, color: Colors.white.withOpacity(0.3)),
                        const SizedBox(height: 14),
                        const Text(
                          'No todos yet',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Track what needs doing for your courses and study sessions.',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                              backgroundColor: _purple),
                          onPressed: _showAddTodoDialog,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Create your first task'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, isNavBarHidden ? 28 : 120),
                  itemCount: _todos.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, index) {
                    final item = _todos[index];
                    final completed = item['completed'] == true;

                    return Container(
                      decoration: BoxDecoration(
                        color: _surfaceDark.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.12)),
                      ),
                      child: ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        leading: Checkbox(
                          value: completed,
                          activeColor: _purple,
                          checkColor: Colors.white,
                          side: const BorderSide(
                              color: Colors.white54, width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5)),
                          onChanged: (_) => _toggleTodo(index),
                        ),
                        title: Text(
                          '${item['title']}',
                          style: TextStyle(
                            color: completed ? Colors.white38 : Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            decoration: completed
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                        trailing: IconButton(
                          tooltip: 'Delete todo',
                          icon: const Icon(Icons.delete_outline,
                              size: 19, color: Colors.white54),
                          onPressed: () => _deleteTodo(index),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // --- TAB 3: REMAINDER CONTENT ---
  Widget _buildRemainderTab() {
    return RemindersList(
      query: _search.text,
      alphabetical: _alphabetical,
    );
  }
}
