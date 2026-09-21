import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/data_providers.dart';

final personalRemindersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  ref.watch(mobileAuthProvider.select((state) => state.user?.id));
  return ref.watch(apiServiceProvider).getPersonalReminders();
});

class ReminderDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialReminder;
  const ReminderDialog({super.key, this.initialReminder});
  @override
  ConsumerState<ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends ConsumerState<ReminderDialog> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late DateTime _due;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialReminder;
    _title = TextEditingController(text: initial?['title']?.toString() ?? '');
    _description =
        TextEditingController(text: initial?['description']?.toString() ?? '');
    final initialDue = initial?['dueAt']?.toString();
    _due = initialDue != null
        ? DateTime.parse(initialDue).toLocal()
        : DateTime.now().add(const Duration(hours: 1));
  }

  @override
  void didUpdateWidget(ReminderDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialReminder != widget.initialReminder) {
      final initial = widget.initialReminder;
      _title.text = initial?['title']?.toString() ?? '';
      _description.text = initial?['description']?.toString() ?? '';
      final initialDue = initial?['dueAt']?.toString();
      if (initialDue != null) {
        _due = DateTime.parse(initialDue).toLocal();
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
        context: context,
        initialDate: _due.isBefore(now) ? now : _due,
        firstDate: DateTime(now.year, now.month, now.day),
        lastDate: DateTime(now.year + 10));
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(_due));
    if (time == null || !mounted) return;
    setState(() => _due =
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_title.text.trim().isEmpty ||
        _title.text.trim().length > 200 ||
        !_due.isAfter(DateTime.now())) {
      setState(() => _error = 'Enter a title and a future reminder time.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.initialReminder != null) {
        final id = (widget.initialReminder!['id'] as num).toInt();
        await ref.read(apiServiceProvider).updatePersonalReminder(
            id, title: _title.text, description: _description.text, dueAt: _due);
      } else {
        await ref.read(apiServiceProvider).createPersonalReminder(
            title: _title.text, description: _description.text, dueAt: _due);
      }
      if (!mounted) return;
      ref.invalidate(personalRemindersProvider);
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save reminder. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialReminder != null;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        backgroundColor: const Color(0xFF0C2758),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.15)),
        ),
        title: Text(isEditing ? 'Edit reminder' : 'Create reminder',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            key: const ValueKey('reminder-title'),
            controller: _title,
            enabled: !_saving,
            maxLength: 200,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Reminder title',
              labelStyle: const TextStyle(color: Color(0xFF27D9D3)),
              hintText: 'e.g., Revise Dynamic Programming',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.35)),
              filled: true,
              fillColor: const Color(0xFF071D43),
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
              counterStyle: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _description,
            enabled: !_saving,
            maxLength: 2000,
            maxLines: 3,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Details (optional)',
              labelStyle: const TextStyle(color: Color(0xFF27D9D3)),
              hintText: 'Add extra context or notes',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.35)),
              filled: true,
              fillColor: const Color(0xFF071D43),
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
              counterStyle: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ),
          ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule, color: Color(0xFF9B5CFF)),
              title: Text(DateFormat('EEE, d MMM y • h:mm a').format(_due),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: const Text('Local time • Tap to change',
                  style: TextStyle(color: Colors.white60)),
              onTap: _saving ? null : _pickDate),
          const SizedBox(height: 6),
          const Text(
              'Push alerts require notification permission and an internet connection. Delivery may be delayed.',
              style: TextStyle(color: Colors.white38, fontSize: 11)),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!,
                  style: const TextStyle(color: Color(0xFFFF6B6B))),
            ),
        ])),
        actions: [
          TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white60))),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF9B5CFF)),
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : (isEditing ? 'Save changes' : 'Save reminder'))),
        ],
      ),
    );
  }
}

class RemindersList extends ConsumerStatefulWidget {
  final String query;
  final bool alphabetical;
  const RemindersList(
      {super.key, required this.query, required this.alphabetical});
  @override
  ConsumerState<RemindersList> createState() => _RemindersListState();
}

class _RemindersListState extends ConsumerState<RemindersList> {
  final _busy = <int>{};
  Future<void> _update(int id, String status) async {
    setState(() => _busy.add(id));
    try {
      await ref.read(apiServiceProvider).updateReminderStatus(id, status);
      ref.invalidate(personalRemindersProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not update reminder. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) =>
      ref.watch(personalRemindersProvider).when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFF9B5CFF))),
            error: (_, __) => Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Could not load reminders',
                  style: TextStyle(color: Colors.white70)),
              TextButton(
                  onPressed: () => ref.invalidate(personalRemindersProvider),
                  child: const Text('Retry',
                      style: TextStyle(color: Color(0xFF9B5CFF)))),
            ])),
            data: (source) {
              final items = source
                  .where((r) => '${r['title']} ${r['description']}'
                      .toLowerCase()
                      .contains(widget.query.trim().toLowerCase()))
                  .toList();
              if (widget.alphabetical) {
                items.sort((a, b) => '${a['title']}'
                    .toLowerCase()
                    .compareTo('${b['title']}'.toLowerCase()));
              }
              final isNavBarHidden = ref.watch(shellNavBarHiddenProvider);
              return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(personalRemindersProvider);
                    await ref.read(personalRemindersProvider.future);
                  },
                  color: const Color(0xFF9B5CFF),
                  backgroundColor: const Color(0xFF104476),
                  child: ListView(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, isNavBarHidden ? 28 : 120),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        if (items.isEmpty)
                          Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                children: [
                                  Icon(Icons.notifications_none_rounded,
                                      size: 48,
                                      color: Colors.white.withOpacity(0.3)),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No reminders found. Tap the floating + to create one.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 13),
                                  ),
                                ],
                              )),
                        for (final r in items) _card(r),
                      ]));
            },
          );

  Future<void> _openEditor(Map<String, dynamic> reminder) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => ReminderDialog(initialReminder: reminder),
    );
    if (updated == true) {
      ref.invalidate(personalRemindersProvider);
    }
  }

  Future<void> _delete(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0C2758),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Colors.white.withOpacity(0.15)),
        ),
        title: const Text('Delete reminder?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
            'Are you sure you want to permanently delete this reminder?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFFF6B6B))),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _busy.add(id));
    try {
      await ref.read(apiServiceProvider).deletePersonalReminder(id);
      ref.invalidate(personalRemindersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reminder deleted')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not delete reminder. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Widget _card(Map<String, dynamic> reminder) {
    final id = (reminder['id'] as num).toInt();
    final due = DateTime.parse('${reminder['dueAt']}').toLocal();
    final status = '${reminder['status']}';
    final delivery = switch (reminder['notificationStatus']) {
      'SENT' => 'Push sent',
      'FAILED' => 'Push failed — check notification settings',
      _ => status == 'PENDING' ? 'Push pending' : 'No further alerts',
    };
    final isPending = status == 'PENDING';
    final isDue = isPending && due.isBefore(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF104476).withOpacity(0.55),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9B5CFF).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.alarm_rounded,
                      color: Color(0xFF9B5CFF), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${reminder['title']}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(DateFormat('EEE, d MMM y • h:mm a').format(due),
                          style: const TextStyle(
                              color: Color(0xFF27D9D3),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDue
                        ? const Color(0xFFFFCF35).withOpacity(0.2)
                        : (isPending
                            ? const Color(0xFF9B5CFF).withOpacity(0.2)
                            : Colors.white.withOpacity(0.1)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDue
                          ? const Color(0xFFFFCF35).withOpacity(0.5)
                          : (isPending
                              ? const Color(0xFF9B5CFF).withOpacity(0.5)
                              : Colors.white24),
                    ),
                  ),
                  child: Text(
                    isDue ? 'DUE' : status,
                    style: TextStyle(
                      color: isDue
                          ? const Color(0xFFFFCF35)
                          : (isPending
                              ? const Color(0xFFBD91EF)
                              : Colors.white60),
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if ('${reminder['description'] ?? ''}'.isNotEmpty)
              Padding(
                  padding: const EdgeInsets.only(top: 10, left: 40),
                  child: Text('${reminder['description']}',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13, height: 1.4))),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Text(
                delivery,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 10, left: 36),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (status == 'PENDING') ...[
                    TextButton.icon(
                        style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF27D9D3)),
                        onPressed: _busy.contains(id)
                            ? null
                            : () => _update(id, 'COMPLETED'),
                        icon: const Icon(Icons.check_circle_outline, size: 16),
                        label: const Text('Complete')),
                    TextButton(
                        style: TextButton.styleFrom(
                            foregroundColor: Colors.white60),
                        onPressed: _busy.contains(id)
                            ? null
                            : () => _update(id, 'CANCELLED'),
                        child: const Text('Cancel')),
                  ],
                  TextButton.icon(
                      key: ValueKey('reminder-edit-$id'),
                      style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFB66BFF)),
                      onPressed: _busy.contains(id)
                          ? null
                          : () => _openEditor(reminder),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit')),
                  TextButton.icon(
                      key: ValueKey('reminder-delete-$id'),
                      style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFFF6B6B)),
                      onPressed: _busy.contains(id)
                          ? null
                          : () => _delete(id),
                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                      label: const Text('Delete')),
                ],
              ),
            ),
          ])),
    );
  }
}
