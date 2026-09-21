import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/providers/org_theme_provider.dart';
import '../../../core/utils/image_url.dart';
import '../../../data/models/placement_drive_model.dart';

/// Decorative accent hues for the info/facility icons — fixed, not theme
/// driven, since this is what gives the popup the colourful "poster" look
/// from the reference design regardless of the org's brand colour.
class _Accent {
  static const blue = Color(0xFF2F80ED);
  static const orange = Color(0xFFF5A623);
  static const green = Color(0xFF27AE60);
  static const purple = Color(0xFF8E44E0);
  static const teal = Color(0xFF12B5C9);
}

/// A deliberately brief card; long content and actions live in the detail
/// popup. Styled to match the courses screen's `LearningCard` (same gradient
/// palettes, 28px radius and white circular action button) so the Courses and
/// Placements tabs read as one design.
class PlacementDriveCard extends ConsumerWidget {
  final PlacementDriveModel drive;
  final String status;
  final bool isEligible;
  final Future<bool> Function() onApply;
  final Future<void> Function() onScheduleSlot;
  const PlacementDriveCard(
      {super.key,
        required this.drive,
        required this.status,
        required this.isEligible,
        required this.onApply,
        required this.onScheduleSlot});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = drive.id % 3;
    const foreground = Colors.white;
    final colors = [
      [const Color(0xFF0C2B64), const Color(0xFF144D9C)],
      [const Color(0xFF081E48), const Color(0xFF103E7D)],
      [const Color(0xFF0A2252), const Color(0xFF1B58A8)],
    ][palette];
    final location = (drive.location ?? '').trim();
    final closed = isDriveClosed(drive);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: colors.first,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('placement-drive-${drive.id}'),
          onTap: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: false,
            backgroundColor: Colors.transparent,
            builder: (_) => PlacementDriveDetails(card: this),
          ),
          child: Ink(
              decoration:
              BoxDecoration(gradient: LinearGradient(colors: colors)),
              child: Stack(children: [
                // Same oversized faint watermark the courses cards use.
                Positioned(
                    right: -25,
                    bottom: -30,
                    child: IgnorePointer(
                        child: Icon(Icons.work_rounded,
                            size: 190,
                            color: Colors.white.withValues(alpha: .06)))),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                              child: Text(drive.role.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Color(0xFF38BDF8),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600))),
                          _StatusPill(
                              status: status,
                              foreground: foreground,
                              base: Colors.white),
                        ]),
                        const SizedBox(height: 8),
                        Text(drive.companyName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: foreground,
                                fontSize: 21,
                                height: 1.17,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 10),
                        Row(children: [
                          Icon(Icons.payments_outlined,
                              size: 15,
                              color: foreground.withValues(alpha: .85)),
                          const SizedBox(width: 6),
                          Text(drive.packageDisplay,
                              style: TextStyle(
                                  color: foreground,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                          if (location.isNotEmpty) ...[
                            const SizedBox(width: 14),
                            Icon(Icons.location_on_outlined,
                                size: 15,
                                color: foreground.withValues(alpha: .85)),
                            const SizedBox(width: 6),
                            Flexible(
                                child: Text(location,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: foreground, fontSize: 12))),
                          ],
                        ]),
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Apply by ${drive.formattedDeadline}',
                                        style: TextStyle(
                                            color: foreground, fontSize: 12)),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: LinearProgressIndicator(
                                            value: closed || !isEligible ? 0 : 1,
                                            minHeight: 3,
                                            color: foreground,
                                            backgroundColor:
                                            foreground.withValues(alpha: .18))),
                                    const SizedBox(height: 6),
                                    Text(
                                        closed
                                            ? 'Applications closed'
                                            : isEligible
                                            ? 'You are eligible to apply'
                                            : 'Minimum criteria not met',
                                        style: TextStyle(
                                            color:
                                            foreground.withValues(alpha: .8),
                                            fontSize: 11)),
                                  ])),
                          const SizedBox(width: 16),
                          Container(
                              width: 52,
                              height: 52,
                              decoration: const BoxDecoration(
                                  shape: BoxShape.circle, color: Colors.white),
                              child: const Icon(Icons.arrow_forward,
                                  color: Colors.black, size: 24)),
                        ]),
                      ]),
                )
              ])),
        ),
      ),
    );
  }
}

/// True once the drive is deactivated or its deadline has passed -- shared with
/// the detail popup so the card and the popup always agree.
bool isDriveClosed(PlacementDriveModel drive) {
  final deadline = DateTime.tryParse(drive.deadline ?? '');
  return drive.isActive == false ||
      (deadline != null &&
          DateTime.now().isAfter(
              DateTime(deadline.year, deadline.month, deadline.day + 1)));
}

/// The application-status chip in the card's top row (OPEN / APPLIED /
/// SELECTED / REJECTED), tinted so it stays legible on all three palettes.
class _StatusPill extends StatelessWidget {
  final String status;
  final Color foreground;
  final Color base;
  const _StatusPill(
      {required this.status, required this.foreground, required this.base});

  @override
  Widget build(BuildContext context) {
    final label = status.toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: base.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(_iconFor(label), size: 13, color: foreground),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                color: foreground,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: .4)),
      ]),
    );
  }

  static IconData _iconFor(String status) => switch (status) {
    'APPLIED' => Icons.outgoing_mail,
    'SELECTED' => Icons.verified_rounded,
    'REJECTED' => Icons.cancel_rounded,
    _ => Icons.work_outline_rounded,
  };
}

/// Company logo with the initial as a fallback, used at the top of the popup.
class _CompanyLogo extends StatelessWidget {
  final PlacementDriveModel drive;
  final double size;
  final Color background;
  const _CompanyLogo(
      {required this.drive,
        this.size = 52,
        this.background = const Color(0xFFFEF3C7)});
  @override
  Widget build(BuildContext context) {
    final fallback = Center(
        child: Text(drive.logoInitial,
            style: TextStyle(
                fontSize: size * 0.42,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary)));
    return Container(
      width: size,
      height: size,
      decoration:
      BoxDecoration(color: background, borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: drive.hasCompanyLogo
          ? Image.network(resolveMediaUrl(drive.companyLogoUrl!),
          fit: BoxFit.contain, errorBuilder: (_, __, ___) => fallback)
          : fallback,
    );
  }
}

/// The detail popup opened by tapping a card -- restyled to match the
/// "Campus Placement Drive" poster design: a navy brand strip, a sky-tinted
/// header with title/company badge, a floating fact strip, a solid navy
/// "JOB DESCRIPTION" bar, a two-column requirements/role layout, a row of
/// colourful facility tiles, and the Apply Now / Schedule action bar.
class PlacementDriveDetails extends ConsumerStatefulWidget {
  final PlacementDriveCard card;
  const PlacementDriveDetails({super.key, required this.card});
  @override
  ConsumerState<PlacementDriveDetails> createState() => _DriveDetailsState();
}

class _DriveDetailsState extends ConsumerState<PlacementDriveDetails> {
  bool _busy = false;
  bool _loadingSlot = false;
  bool _booked = false;
  late String _status;
  @override
  void initState() {
    super.initState();
    _status = widget.card.status;
    if (widget.card.drive.isInternal) _checkSlot();
  }

  Future<void> _checkSlot() async {
    setState(() => _loadingSlot = true);
    try {
      final api = ref.read(apiServiceProvider);
      final userId = await api.getCurrentUserId();
      final slots = await api.getInterviewSlotsForDrive(widget.card.drive.id);
      if (mounted) {
        setState(() => _booked = userId != null &&
            slots.any((slot) => slot['bookedByUserId'] == userId));
      }
    } finally {
      if (mounted) setState(() => _loadingSlot = false);
    }
  }

  Future<void> _apply() async {
    setState(() => _busy = true);
    try {
      final success = await widget.card.onApply();
      if (mounted && success) setState(() => _status = 'APPLIED');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final drive = card.drive;
    final theme = ref.watch(orgThemeProvider);
    final orgName = ref.watch(orgNameProvider).valueOrNull ?? 'Organization';
    final closed = isDriveClosed(drive);
    final canApply = !closed && card.isEligible && _status == 'OPEN';
    final location = (drive.location ?? '').trim();
    final navy = theme.primary;


    final requirements = <String>[
      if (drive.minAttendancePercent != null)
        'Attendance: ${drive.minAttendancePercent!.round()}% minimum',
      if (drive.minCourseCompletionPercent != null)
        'Course completion: ${drive.minCourseCompletionPercent!.round()}% minimum',
      if (drive.minAssignmentAvgPercent != null)
        'Assignment average: ${drive.minAssignmentAvgPercent!.round()}% minimum',
      if (drive.minExamAvgPercent != null)
        'Exam average: ${drive.minExamAvgPercent!.round()}% minimum',
      if (drive.minAttendancePercent == null &&
          drive.minCourseCompletionPercent == null &&
          drive.minAssignmentAvgPercent == null &&
          drive.minExamAvgPercent == null)
        (drive.eligibility ?? '').trim().isEmpty
            ? 'No additional requirements provided.'
            : drive.eligibility!,
    ];

    final roleDetails = <MapEntry<String, String>>[
      MapEntry('Position', drive.role),
      MapEntry('Type', drive.isInternal ? 'Campus placement' : 'External opportunity'),
      MapEntry('Package', drive.packageDisplay),
      if (location.isNotEmpty) MapEntry('Work location', location),
      MapEntry('Status', _status),
    ];

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .88),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        child: Container(
          color: const Color(0xFF071D43),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            margin: const EdgeInsets.only(top: 8, bottom: 4),
                            width: 42,
                            height: 5,
                            decoration: BoxDecoration(
                                color: Colors.white24, borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                        Container(
                          color: const Color(0xFF051838),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(children: [
                            _CompanyLogo(drive: drive, size: 34, background: Colors.white),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(orgName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700))),
                            IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close_rounded, color: Colors.white)),
                          ]),
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(18, 22, 18, 30),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF0C2B64), Color(0xFF071D43)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                flex: 6,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      drive.isInternal
                                          ? 'CAMPUS\nPLACEMENT DRIVE'
                                          : 'EXTERNAL\nPLACEMENT\nOPPORTUNITY',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 19,
                                          height: 1.14,
                                          fontWeight: FontWeight.w900),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(children: [
                                      Container(
                                          width: 28,
                                          height: 2,
                                          decoration: BoxDecoration(
                                              color: const Color(0xFF27D9D3).withOpacity(0.55),
                                              borderRadius: BorderRadius.circular(2))),
                                      const SizedBox(width: 6),
                                      const Icon(Icons.circle, size: 4, color: Color(0xFF27D9D3)),
                                    ]),
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(colors: [Color(0xFF104476), Color(0xFF0C2B64)]),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.apartment_rounded, color: Colors.white, size: 12),
                                          const SizedBox(width: 5),
                                          Flexible(
                                            child: Text(
                                              drive.companyName.toUpperCase(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: .3),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      drive.role,
                                      style: const TextStyle(
                                          color: Color(0xFF38BDF8),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 5,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: SizedBox(
                                    height: 108,
                                    width: double.infinity,
                                    child: drive.hasCompanyLogo
                                        ? Image.network(
                                      resolveMediaUrl(drive.companyLogoUrl!),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => _bannerFallback(navy),
                                    )
                                        : _bannerFallback(navy),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Transform.translate(
                          offset: const Offset(0, -24),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _InfoStrip(theme: theme, drive: drive, closed: closed),
                          ),
                        ),
                        Transform.translate(
                          offset: const Offset(0, -12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _NavyBar(
                                  color: const Color(0xFF104476),
                                  icon: Icons.work_rounded,
                                  label: 'JOB DESCRIPTION'),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                                child: _JobDescriptionSection(
                                  theme: theme,
                                  drive: drive,
                                  requirements: requirements,
                                  roleDetails: roleDetails,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                                child: _FacilitiesStrip(
                                    theme: theme, drive: drive, isEligible: card.isEligible),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF051838),
                    border: Border(top: BorderSide(color: Colors.white.withOpacity(0.12))),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFF27D9D3), Color(0xFF0EA5E9)]),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                                color: const Color(0xFF27D9D3).withOpacity(0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: canApply && !_busy ? _apply : null,
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                      _status == 'APPLIED'
                                          ? Icons.check_circle
                                          : Icons.send_rounded,
                                      color: const Color(0xFF071D43),
                                      size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    _busy
                                        ? 'PLEASE WAIT…'
                                        : _status == 'OPEN'
                                        ? 'APPLY NOW'
                                        : _status,
                                    style: const TextStyle(
                                        color: Color(0xFF071D43),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        letterSpacing: .4),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (drive.isInternal) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFF27D9D3), width: 1.4),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(24),
                              onTap: canApply && !_busy && !_loadingSlot
                                  ? () async {
                                setState(() => _busy = true);
                                try {
                                  await card.onScheduleSlot();
                                  if (mounted) await _checkSlot();
                                } finally {
                                  if (mounted) setState(() => _busy = false);
                                }
                              }
                                  : null,
                              child: const Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.event_available_rounded, color: Color(0xFF27D9D3), size: 16),
                                    SizedBox(width: 8),
                                    Text(
                                      'SCHEDULE',
                                      style: TextStyle(
                                          color: Color(0xFF27D9D3),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                          letterSpacing: .3),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bannerFallback(Color navy) => Container(
    color: navy.withValues(alpha: .08),
    alignment: Alignment.center,
    child: Icon(Icons.apartment_rounded, size: 36, color: navy.withValues(alpha: .5)),
  );
}

/// Floating white fact strip — Deadline / Package / Location — overlapping
/// the bottom of the sky header, each with its own coloured icon.
class _InfoStrip extends StatelessWidget {
  final dynamic theme;
  final PlacementDriveModel drive;
  final bool closed;
  const _InfoStrip({required this.theme, required this.drive, required this.closed});

  @override
  Widget build(BuildContext context) {
    final location = (drive.location ?? '').trim();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0C2B64),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E4E8C).withOpacity(0.5)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceEvenly,
        runSpacing: 12,
        children: [
          _InfoItem(
              theme: theme,
              icon: Icons.calendar_today_rounded,
              iconColor: _Accent.blue,
              label: 'DEADLINE',
              value: closed ? 'Closed' : drive.formattedDeadline),
          _InfoItem(
              theme: theme,
              icon: Icons.payments_rounded,
              iconColor: _Accent.green,
              label: 'PACKAGE',
              value: drive.packageDisplay),
          if (location.isNotEmpty)
            _InfoItem(
                theme: theme,
                icon: Icons.location_on_rounded,
                iconColor: _Accent.purple,
                label: 'LOCATION',
                value: location),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final dynamic theme;
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  const _InfoItem(
      {required this.theme,
        required this.icon,
        required this.iconColor,
        required this.label,
        required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
              radius: 15,
              backgroundColor: iconColor.withValues(alpha: .12),
              child: Icon(icon, size: 15, color: iconColor)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: iconColor,
                        letterSpacing: .3)),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Solid, fully-rounded navy bar — "JOB DESCRIPTION" section label.
class _NavyBar extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  const _NavyBar({required this.color, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: .4)),
      ]),
    );
  }
}

/// Role header + two-column Key Requirements / Job Role & Opportunity.
class _JobDescriptionSection extends StatelessWidget {
  final dynamic theme;
  final PlacementDriveModel drive;
  final List<String> requirements;
  final List<MapEntry<String, String>> roleDetails;
  const _JobDescriptionSection(
      {required this.theme,
        required this.drive,
        required this.requirements,
        required this.roleDetails});

  @override
  Widget build(BuildContext context) {
    final description = (drive.description ?? '').trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: const Color(0xFF27D9D3).withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.code_rounded, color: Color(0xFF27D9D3)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(drive.role,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 3),
                  Text(
                      description.isEmpty ? 'No description provided.' : description,
                      style: const TextStyle(fontSize: 12.5, color: Colors.white70, height: 1.35)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, constraints) {
          final requirementsCol = _ColumnBlock(
            theme: theme,
            icon: Icons.list_alt_rounded,
            title: 'Key Requirements',
            children: requirements.map((e) => _bullet(theme, e)).toList(),
          );
          final roleCol = _ColumnBlock(
            theme: theme,
            icon: Icons.person_outline_rounded,
            title: 'Job Role & Opportunity',
            children: roleDetails.map((e) => _keyValue(theme, e.key, e.value)).toList(),
          );
          if (constraints.maxWidth < 380) {
            return Column(children: [requirementsCol, const SizedBox(height: 18), roleCol]);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Expanded(child: requirementsCol), const SizedBox(width: 16), Expanded(child: roleCol)],
          );
        }),
      ],
    );
  }
}

class _ColumnBlock extends StatelessWidget {
  final dynamic theme;
  final IconData icon;
  final String title;
  final List<Widget> children;
  const _ColumnBlock(
      {required this.theme, required this.icon, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          CircleAvatar(
              radius: 11, backgroundColor: const Color(0xFF27D9D3), child: Icon(icon, size: 12, color: const Color(0xFF071D43))),
          const SizedBox(width: 8),
          Expanded(
              child: Text(title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white))),
        ]),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }
}

Widget _bullet(dynamic theme, String text) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
          padding: EdgeInsets.only(top: 5),
          child: Icon(Icons.circle, size: 5, color: Color(0xFF27D9D3))),
      const SizedBox(width: 8),
      Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: 12.5, color: Colors.white70, height: 1.35))),
    ],
  ),
);

Widget _keyValue(dynamic theme, String key, String value) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: RichText(
    text: TextSpan(
      style: const TextStyle(fontSize: 12.5, color: Colors.white70, height: 1.35),
      children: [
        const TextSpan(text: '•  '),
        TextSpan(text: '$key: ', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
        TextSpan(text: value),
      ],
    ),
  ),
);

/// Row of colourful facility tiles — Package / Location / Eligibility / Deadline.
class _FacilitiesStrip extends StatelessWidget {
  final dynamic theme;
  final PlacementDriveModel drive;
  final bool isEligible;
  const _FacilitiesStrip({required this.theme, required this.drive, required this.isEligible});

  @override
  Widget build(BuildContext context) {
    final location = (drive.location ?? '').trim();
    final tiles = [
      _FacilityTile(
          theme: theme,
          icon: Icons.currency_rupee_rounded,
          color: _Accent.orange,
          title: 'Package',
          subtitle: drive.packageDisplay),
      _FacilityTile(
          theme: theme,
          icon: Icons.place_outlined,
          color: _Accent.purple,
          title: 'Location',
          subtitle: location.isEmpty ? 'Not specified' : location),
      _FacilityTile(
          theme: theme,
          icon: Icons.verified_user_outlined,
          color: _Accent.green,
          title: 'Eligibility',
          subtitle: isEligible ? 'Verified' : 'Not verified'),
      _FacilityTile(
          theme: theme,
          icon: Icons.event_busy_rounded,
          color: _Accent.teal,
          title: 'Deadline',
          subtitle: drive.formattedDeadline),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final crossAxisCount = constraints.maxWidth < 380 ? 2 : 4;
      return GridView.count(
        crossAxisCount: crossAxisCount,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: crossAxisCount == 2 ? 2.6 : 1.05,
        children: tiles,
      );
    });
  }
}

class _FacilityTile extends StatelessWidget {
  final dynamic theme;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const _FacilityTile(
      {required this.theme,
        required this.icon,
        required this.color,
        required this.title,
        required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0C2B64),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E4E8C).withOpacity(0.5)),
      ),
      child: Row(children: [
        CircleAvatar(
            radius: 14, backgroundColor: color.withValues(alpha: .14), child: Icon(icon, size: 15, color: color)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white, height: 1.2)),
              const SizedBox(height: 2),
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: Colors.white70)),
            ],
          ),
        ),
      ]),
    );
  }
}