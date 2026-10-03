import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/routes.dart';
import '../../../core/providers/subscription_provider.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/providers/org_theme_provider.dart';
import '../../../core/widgets/common_header.dart';
import '../../../data/models/placement_drive_model.dart';
import '../browser/in_app_browser_screen.dart';
import 'placement_drive_card.dart';

/// The placements tab, laid out to match the redesigned courses screen
/// (`LearningCollection` in `screens/courses/learning_collection.dart`): the
/// same lavender page, rounded hero with a bold two-line title, original vector
/// artwork and count chips, the same white filter panel, and the same gradient
/// cards. Tapping a card opens the drive detail popup
/// ([PlacementDriveCard] -> `_DriveDetails`).
class PlacementDrivesScreen extends ConsumerStatefulWidget {
  final String initialFilter;
  const PlacementDrivesScreen({super.key, this.initialFilter = 'All'});
  @override
  ConsumerState<PlacementDrivesScreen> createState() =>
      _PlacementDrivesScreenState();
}

class _PlacementDrivesScreenState extends ConsumerState<PlacementDrivesScreen> {
  /// Application-status filters, styled exactly like the courses screen's
  /// (icon + label chips inside the white panel).
  static const _filters = [
    ('All', Icons.palette, Color(0xFF8323CF)),
    ('Open', Icons.work_outline_rounded, Color(0xFF095EC3)),
    ('Applied', Icons.outgoing_mail, Color(0xFFD75B1A)),
    ('Selected', Icons.verified_rounded, Color(0xFF168722)),
    ('Rejected', Icons.cancel_rounded, Color(0xFFC62828)),
  ];

  late String _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
  }

  @override
  Widget build(BuildContext context) {
    final activePlanIds = ref.watch(subscriptionProvider).activePlanIds;
    final overview = ref.watch(placementOverviewProvider).asData?.value ??
        const <String, dynamic>{};
    final metrics =
        ref.watch(placementMetricsProvider).asData?.value ?? <String, double>{};

    return CommonHeaderScaffold(
      subtitle: 'Placements',
      backgroundColor: const Color(0xFF061D43),
      body: ref.watch(placementDrivesProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(
                child: TextButton(
                    onPressed: () => ref.invalidate(placementDrivesProvider),
                    child:
                        const Text('Failed to load placement drives. Retry'))),
            data: (drives) {
              // Plan-gated drives stay hidden until the student upgrades, the
              // same rule the courses tab uses.
              final accessible =
                  drives.where((d) => d.isAccessible(activePlanIds)).toList();
              final statusByDrive = _statusByDrive(overview);
              final visible = _filter == 'All'
                  ? accessible
                  : accessible
                      .where((d) =>
                          (statusByDrive[d.id] ?? 'OPEN') ==
                          _filter.toUpperCase())
                      .toList();
              final appliedCount =
                  (overview['appliedCount'] as num?)?.toInt() ??
                      statusByDrive.values.where((s) => s != 'OPEN').length;
              return _body(
                  context, accessible, visible, statusByDrive, metrics,
                  appliedCount, overview);
            },
          ),
    );
  }

  /// The scrollable body — the dark glass placement dashboard from the reference.

  /// count chips, filter panel and the drive cards.
  Widget _body(
      BuildContext context,
      List<PlacementDriveModel> accessible,
      List<PlacementDriveModel> visible,
      Map<int, String> statusByDrive,
      Map<String, double> metrics,
      int appliedCount,
      Map<String, dynamic> overview) {
    final open = (overview['openCount'] as num?)?.toInt() ?? 0;
    final selected = (overview['selectedCount'] as num?)?.toInt() ?? 0;
    final rejected = (overview['rejectedCount'] as num?)?.toInt() ?? 0;
    final profileValues = metrics.values.where((value) => value >= 0).toList();
    final profileScore = profileValues.isEmpty ? 0 : (profileValues.reduce((a, b) => a + b) / profileValues.length).round();
    return Stack(children: [
      const Positioned.fill(child: _PlacementBackdrop()),
      SafeArea(
        top: false,
        bottom: false,
        left: false,
        right: false,
        child: RefreshIndicator(
        onRefresh: _refresh,
        color: const Color(0xFFB66BFF),
        backgroundColor: const Color(0xFF123E72),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
          children: [
            _referenceHeader(context),
            const SizedBox(height: 14),
            _referencePlacementStats(profileScore, appliedCount, open, selected),
            const SizedBox(height: 12),
            _referenceCategoryTabs(
                total: accessible.length,
                applied: appliedCount,
                open: open,
                selected: selected,
                rejected: rejected),
            const SizedBox(height: 12),
            if (visible.isEmpty)
              _referenceEmpty(_filter == 'All' ? 'No placement drives available' : 'No $_filter placement drives')
            else
              ...visible.map((drive) => _ReferencePlacementCard(
                drive: drive,
                status: statusByDrive[drive.id] ?? 'OPEN',
                isEligible: drive.isEligibleFor(metrics),
                profileScore: profileScore,
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  backgroundColor: ref.read(orgThemeProvider).surface,
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
                  builder: (_) => PlacementDriveDetails(
                    card: PlacementDriveCard(
                      drive: drive,
                      status: statusByDrive[drive.id] ?? 'OPEN',
                      isEligible: drive.isEligibleFor(metrics),
                      onApply: () => _applyAndOpenLink(ref, drive),
                      onScheduleSlot: () => _showSlotPicker(ref, drive),
                    ),
                  ),
                ),
                onApply: () => _applyAndOpenLink(ref, drive),
              )),
            const SizedBox(height: 8),
          ],
        ),
      )),
    ]);
  }

  Widget _referenceHeader(BuildContext context) => Row(children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFF9B5CFF), borderRadius: BorderRadius.circular(13), boxShadow: [BoxShadow(color: const Color(0xFF9B5CFF).withOpacity(.55), blurRadius: 18)]), child: const Icon(Icons.work_outline_rounded, color: Colors.white, size: 25)),
        const SizedBox(width: 12),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Placement Drives', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)), SizedBox(height: 3), Text('Your next opportunity is here', style: TextStyle(color: Colors.white70, fontSize: 11))])),
        PopupMenuButton<String>(
          tooltip: 'Placement support',
          color: const Color(0xFF123E72),
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 24),
          onSelected: (value) {
            if (value == 'support') context.push(AppRoutes.supportRequest);
          },
          itemBuilder: (_) => const [
            PopupMenuItem<String>(
              value: 'support',
              child: Row(children: [
                Icon(Icons.support_agent_outlined, color: Color(0xFF27D9D3), size: 19),
                SizedBox(width: 10),
                Text('Raise / view support requests', style: TextStyle(color: Colors.white, fontSize: 12)),
              ]),
            ),
          ],
        ),
      ]);

  Widget _referenceCategoryTabs({required int total, required int applied, required int open, required int selected, required int rejected}) {
    final counts = <String, int>{
      'All': total,
      'Open': open,
      'Applied': applied,
      'Selected': selected,
      'Rejected': rejected,
    };
    return _GlassPanel(
      padding: const EdgeInsets.all(6),
      child: Row(
        children: _filters.map((filter) {
          final active = _filter == filter.$1;
          final count = counts[filter.$1] ?? 0;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                onTap: () => setState(() => _filter = filter.$1),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFF8B4DFF) : Colors.white.withOpacity(.06),
                    border: Border.all(color: active ? const Color(0xFFBDA0FF) : Colors.white12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(children: [
                    Icon(filter.$2, color: active ? Colors.white : filter.$3, size: 17),
                    const SizedBox(height: 3),
                    Text(filter.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: active ? Colors.white : Colors.white70, fontSize: 9, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text('$count', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                  ]),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _referenceEmpty(String message) => _GlassPanel(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Text(message,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ),
      );

  Widget _referencePlacementStats(int profileScore, int applied, int open, int selected) => _GlassPanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.bar_chart, color: Colors.white70, size: 15), SizedBox(width: 6), Text('Placement Stats', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)), Spacer(), Text('Live', style: TextStyle(color: Colors.white70, fontSize: 9))]),
          const SizedBox(height: 8),
          Row(children: [
            _ReferenceMiniStat(label: 'Your Profile Score', value: '$profileScore', color: const Color(0xFF27D9D3)),
            _ReferenceMiniStat(label: 'Applications Sent', value: '$applied', color: const Color(0xFF48AFFF)),
            _ReferenceMiniStat(label: 'Open Drives', value: '$open', color: const Color(0xFFA66AFF)),
            _ReferenceMiniStat(label: 'Offers Received', value: '$selected', color: const Color(0xFFFFCF35)),
          ]),
        ]));

  /// Icon + label filter chips, identical in shape to the courses screen's.
  Widget _filterBar() => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final (name, icon, color) in _filters)
          Padding(
              padding: const EdgeInsets.only(right: 6),
              child: TextButton.icon(
                  onPressed: () => setState(() => _filter = name),
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.black,
                      backgroundColor: _filter == name
                          ? color.withValues(alpha: .08)
                          : null,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10)),
                  icon: Icon(icon, color: color, size: 21),
                  label: Text(name, style: const TextStyle(fontSize: 12)))),
      ]));

  Widget _circleAction(
          {required String tooltip,
          required IconData icon,
          required VoidCallback onPressed}) =>
      IconButton.filled(
          tooltip: tooltip,
          onPressed: onPressed,
          style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              minimumSize: const Size(48, 48)),
          icon: Icon(icon));

  /// The hero's pill counter — same shape/colors as the courses screen's.
  Widget _countChip(IconData icon, String label, bool dark) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
          color: dark ? const Color(0xFF001023) : Colors.white,
          borderRadius: BorderRadius.circular(32)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon,
            size: 22, color: dark ? Colors.white : const Color(0xFF128820)),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(
                color: dark ? Colors.white : Colors.black,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ]));

  Future<void> _refresh() async {
    ref.invalidate(placementDrivesProvider);
    ref.invalidate(placementOverviewProvider);
    ref.invalidate(placementMetricsProvider);
    await ref.read(placementDrivesProvider.future);
  }

  /// driveId -> uppercase application status ('OPEN' when never applied).
  Map<int, String> _statusByDrive(Map<String, dynamic> overview) {
    final items = (overview['items'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    return {
      for (final item in items)
        if (item['driveId'] != null)
          (item['driveId'] as num).toInt():
              (item['status']?.toString() ?? 'OPEN').toUpperCase(),
    };
  }

  Future<bool> _applyAndOpenLink(
      WidgetRef ref, PlacementDriveModel drive) async {
    final success =
        await ref.read(apiServiceProvider).applyToPlacementDrive(drive.id);
    if (!mounted) return success;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Application could not be submitted. Please try again.')));
      return false;
    }
    ref.invalidate(placementOverviewProvider);
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Application submitted successfully.')));
    final link = drive.applyLink;
    if (link == null || link.isEmpty) return true;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InAppBrowserScreen(
            url: link, title: '${drive.companyName} - Apply'),
      ),
    );
    return true;
  }

  /// Closes the loop between an INTERNAL placement drive and actual
  /// interview tracking: shows the admin-created open slots for this drive
  /// and lets the student book one ("Schedule my slot").
  Future<void> _showSlotPicker(WidgetRef ref, PlacementDriveModel drive) async {
    final api = ref.read(apiServiceProvider);
    final slots = await api.getInterviewSlotsForDrive(drive.id);
    final userId = await api.getCurrentUserId();
    if (!mounted) return;

    // If this student already holds a slot on this drive, show it instead of
    // letting them pick another one -- only an admin resetting the slot frees
    // it back up.
    Map<String, dynamic>? mySlot;
    for (final s in slots) {
      final bookedBy = (s['bookedByUserId'] as num?)?.toInt();
      if (bookedBy != null && bookedBy == userId) {
        mySlot = s;
        break;
      }
    }

    final available = slots.where((s) => s['status'] == 'AVAILABLE').toList();
    final theme = ref.read(orgThemeProvider);
    final sheet = ref;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isHidden = ref.read(shellNavBarHiddenProvider);
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0C2B64), Color(0xFF071D43)],
              ),
              border: Border.all(color: const Color(0xFF1E4E8C)),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, isHidden ? 24 : 110),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  Text(
                    mySlot != null
                        ? 'Your Interview Slot'
                        : 'Available Interview Slots',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    drive.companyName,
                    style: const TextStyle(color: Color(0xFF27D9D3), fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  if (mySlot != null)
                    _BookedSlotSummary(theme: theme, slot: mySlot)
                  else if (available.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No open slots right now. Check back later.',
                          style: TextStyle(color: Colors.white60),
                        ),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 360),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: available.length,
                        itemBuilder: (context, index) {
                          final slot = available[index];
                          final slotTime = (slot['slotTime'] ?? '').toString().replaceFirst('T', '  ');
                          final location = slot['location'] as String? ?? '';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withOpacity(0.12)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF27D9D3).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.schedule_rounded, color: Color(0xFF27D9D3), size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        slotTime,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5),
                                      ),
                                      if (location.isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          location,
                                          style: const TextStyle(color: Colors.white60, fontSize: 11.5),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () async {
                                    final success = await api.bookInterviewSlot(slot['id'] as int);
                                    if (!ctx.mounted) return;
                                    Navigator.pop(ctx);
                                    sheet.invalidate(placementOverviewProvider);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(success
                                            ? 'Interview slot booked!'
                                            : 'Failed to book slot. Try another.'),
                                        backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF27D9D3),
                                    foregroundColor: const Color(0xFF041838),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  ),
                                  child: const Text('Book', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
}

/// The confirmed slot a student already holds for a drive -- shown instead of
/// the booking list so they can't pick a second one out from under it.
class _BookedSlotSummary extends StatelessWidget {
  final dynamic theme;
  final Map<String, dynamic> slot;
  const _BookedSlotSummary({required this.theme, required this.slot});

  @override
  Widget build(BuildContext context) {
    final location = (slot['location'] ?? '').toString();
    final notes = (slot['notes'] ?? '').toString();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withOpacity(0.12),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text('Your slot is confirmed',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Color(0xFF10B981), fontSize: 14)),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.schedule_rounded, size: 16, color: Colors.white70),
            const SizedBox(width: 8),
            Text((slot['slotTime'] ?? '').toString().replaceFirst('T', '  '),
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13)),
          ]),
          if (location.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.location_on_rounded, size: 16, color: Colors.white70),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(location,
                      style: const TextStyle(color: Colors.white70, fontSize: 12))),
            ]),
          ],
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.info_outline_rounded, size: 16, color: Colors.white70),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(notes,
                      style: const TextStyle(color: Colors.white60, fontSize: 11.5))),
            ]),
          ],
          if ((slot['facultyName'] ?? '').toString().isNotEmpty || (slot['facultyEmail'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.person_outline_rounded, size: 16, color: Colors.white70),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  (slot['facultyName'] ?? '').toString().isNotEmpty && (slot['facultyEmail'] ?? '').toString().isNotEmpty
                      ? 'Interviewer: ${slot['facultyName']} (${slot['facultyEmail']})'
                      : 'Interviewer: ${(slot['facultyName'] ?? '').toString().isNotEmpty ? slot['facultyName'] : slot['facultyEmail']}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ]),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                final slotId = slot['id'];
                final roomCode = 'AXIS-INT-$slotId';
                context.push(AppRoutes.interviewRoomFor(roomCode));
              },
              icon: const Icon(Icons.video_call_rounded, color: Colors.white, size: 20),
              label: const Text(
                'Join 1-1 Interview Room',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text('Contact your institute if you need to reschedule.',
              style: TextStyle(fontSize: 12, color: Colors.white54)),
        ],
      ),
    );
  }
}

extension on PlacementDriveModel {
  bool isAccessible(Set<int>? activePlanIds) {
    if (planId == null) return true;
    if (activePlanIds == null) return false;
    return activePlanIds.contains(planId);
  }
}

/// Original local vector illustration (a briefcase, an offer letter and a
/// "shortlisted" tick) drawn on the same 160x140 canvas as the courses screen's
/// `LearningArtwork`, rather than shipping a 3-D asset.
class PlacementArtwork extends CustomPainter {
  const PlacementArtwork();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 160, size.height / 140);
    final paint = Paint();

    // Offer letter peeking out from behind the briefcase.
    canvas.save();
    canvas.translate(104, 50);
    canvas.rotate(-0.22);
    final letter = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-36, -44, 72, 88), const Radius.circular(10));
    canvas.drawShadow(Path()..addRRect(letter), Colors.black38, 5, true);
    canvas.drawRRect(letter, paint..color = const Color(0xFFFFFFFF));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-26, -34, 30, 9), const Radius.circular(4)),
        paint..color = const Color(0xFF05ADC2));
    for (var i = 0; i < 4; i++) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(-26, -14.0 + i * 15, 52 - i * 7, 7),
              const Radius.circular(3)),
          paint..color = const Color(0xFFD9E2DD));
    }
    canvas.restore();

    // Briefcase body, handle and latch.
    final body = RRect.fromRectAndRadius(
        const Rect.fromLTWH(14, 64, 116, 62), const Radius.circular(14));
    canvas.drawShadow(Path()..addRRect(body), Colors.black45, 6, true);
    canvas.drawRRect(
        body,
        paint
          ..shader = const LinearGradient(
                  colors: [Color(0xFF34383C), Color(0xFF03080C)])
              .createShader(const Rect.fromLTWH(14, 64, 116, 62)));
    paint.shader = null;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(58, 52, 28, 18), const Radius.circular(8)),
        paint..color = const Color(0xFF34383C));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(63, 56, 18, 12), const Radius.circular(6)),
        paint..color = const Color(0xFFEDEFF2));
    canvas.drawLine(const Offset(14, 84), const Offset(130, 84),
        paint..color = const Color(0x22FFFFFF)..strokeWidth = 2);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(64, 78, 16, 13), const Radius.circular(4)),
        paint..color = const Color(0xFFFFBF03));

    // "Shortlisted" tick badge.
    canvas.drawCircle(
        const Offset(32, 34), 19, paint..color = const Color(0xFFFFBB05));
    canvas.drawPath(
        Path()
          ..moveTo(23, 34)
          ..lineTo(30, 41)
          ..lineTo(42, 27),
        paint
          ..color = const Color(0xFF3A2400)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PlacementArtwork oldDelegate) => false;
}


class _PlacementBackdrop extends StatelessWidget {
  const _PlacementBackdrop();
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _PlacementBackdropPainter());
}

class _PlacementBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF06234E), Color(0xFF071A3E), Color(0xFF03132F)]).createShader(rect));
    for (final point in [Offset(size.width * .15, size.height * .12), Offset(size.width * .82, size.height * .22), Offset(size.width * .28, size.height * .62)]) {
      canvas.drawCircle(point, 90, Paint()..color = const Color(0xFF1676C6).withOpacity(.12)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 38));
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _GlassPanel({required this.child, this.padding = const EdgeInsets.all(10)});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: const Color(0xFF123E72).withOpacity(.72),
              border: Border.all(color: const Color(0xFF4D9CD0).withOpacity(.55)),
              borderRadius: BorderRadius.circular(15),
            ),
            child: child,
          ),
        ),
      );
}

class _ReferenceStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _ReferenceStat({required this.icon, required this.value, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          decoration: const BoxDecoration(border: Border(right: BorderSide(color: Colors.white12))),
          child: Column(children: [
            Container(width: 28, height: 28, decoration: BoxDecoration(color: color.withOpacity(.9), shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(.4), blurRadius: 10)]), child: Icon(icon, color: Colors.white, size: 16)),
            const SizedBox(height: 5),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 8)),
          ]),
        ),
      );
}

class _ReferenceMiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _ReferenceMiniStat({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 5),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 3),
          decoration: BoxDecoration(color: Colors.white.withOpacity(.07), border: Border.all(color: Colors.white12), borderRadius: BorderRadius.circular(10)),
          child: Column(children: [Icon(Icons.analytics_outlined, color: color, size: 17), const SizedBox(height: 3), Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)), Text(label, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(color: Colors.white70, fontSize: 7))]),
        ),
      );
}

class _ReferencePlacementCard extends StatelessWidget {
  final PlacementDriveModel drive;
  final String status;
  final bool isEligible;
  final int profileScore;
  final VoidCallback onTap;
  final Future<bool> Function() onApply;
  const _ReferencePlacementCard({required this.drive, required this.status, required this.isEligible, required this.profileScore, required this.onTap, required this.onApply});

  Color get _accent => switch (status) {
        'APPLIED' => const Color(0xFF27D9D3),
        'SELECTED' => const Color(0xFFFFCF35),
        'REJECTED' => const Color(0xFFFF6691),
        _ => const Color(0xFF48AFFF),
      };

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _accent.withOpacity(.16),
              border: Border.all(color: _accent.withOpacity(.75)),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [BoxShadow(color: _accent.withOpacity(.15), blurRadius: 14)],
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 53, height: 53, alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFF08254A), border: Border.all(color: _accent.withOpacity(.55)), borderRadius: BorderRadius.circular(12)), child: Text(drive.logoInitial, style: TextStyle(color: _accent, fontSize: 22, fontWeight: FontWeight.w900))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Expanded(child: Text(drive.companyName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800))), _StatusBadge(status: status, color: _accent)]),
                const SizedBox(height: 3),
                Text(drive.role, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                const SizedBox(height: 7),
                Wrap(spacing: 10, runSpacing: 4, children: [if (drive.deadline?.isNotEmpty ?? false) _Meta(icon: Icons.calendar_today_outlined, text: 'Apply by ${drive.formattedDeadline}'), if ((drive.location ?? '').trim().isNotEmpty) _Meta(icon: Icons.location_on_outlined, text: drive.location!.trim()), _Meta(icon: Icons.payments_outlined, text: drive.packageDisplay)]),
                const SizedBox(height: 8),
                Row(children: [Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: status == 'OPEN' ? (isEligible ? 1 : 0) : 1, minHeight: 4, color: _accent, backgroundColor: Colors.white12))), const SizedBox(width: 8), if (status == 'OPEN' && isEligible) InkWell(onTap: () async => await onApply(), child: Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(12)), child: const Text('APPLY', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800))))]),
                if (!isEligible && status == 'OPEN') const Padding(padding: EdgeInsets.only(top: 4), child: Text('Eligibility criteria not met', style: TextStyle(color: Colors.white60, fontSize: 8))),
              ])),
              const SizedBox(width: 7),
              Icon(Icons.arrow_forward_ios_rounded, color: _accent, size: 16),
            ]),
          ),
        ),
      );
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final Color color;
  const _StatusBadge({required this.status, required this.color});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(.2), borderRadius: BorderRadius.circular(12)), child: Text(status, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w800)));
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Meta({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: Colors.white60, size: 11), const SizedBox(width: 3), Text(text, style: const TextStyle(color: Colors.white70, fontSize: 8))]);
}
