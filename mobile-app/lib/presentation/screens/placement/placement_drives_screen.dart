import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/routes.dart';
import '../../../core/providers/subscription_provider.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/widgets/common_header.dart';
import '../../../data/models/placement_drive_model.dart';
import '../browser/in_app_browser_screen.dart';

class PlacementDrivesScreen extends ConsumerStatefulWidget {
  const PlacementDrivesScreen({super.key});
  @override
  ConsumerState<PlacementDrivesScreen> createState() => _PlacementDrivesScreenState();
}

class _PlacementDrivesScreenState extends ConsumerState<PlacementDrivesScreen> {
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final activePlanIds = ref.watch(subscriptionProvider).activePlanIds;
    final drivesAsync = ref.watch(placementDrivesProvider);

    return Scaffold(
      appBar: CommonHeader(
        title: 'Placements',
        actions: [
          IconButton(
            icon: const Icon(Icons.support_agent_outlined, color: Colors.white),
            tooltip: 'Request Support',
            onPressed: () => context.push(AppRoutes.supportRequest),
          ),
        ],
      ),
      body: drivesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text('Failed to load placement drives', style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(placementDrivesProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (drives) {
          final accessible = drives.where((d) => d.isAccessible(activePlanIds)).toList();
          final filtered = _selectedFilter == 'All'
              ? accessible
              : accessible.where((d) => d.category == _selectedFilter).toList();
          final filters = <String>{'All'};
          for (final d in accessible) {
            filters.add(d.category);
          }

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF0F172A), const Color(0xFF0F172A).withOpacity(0.85)],
                  ),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Placement Dashboard', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('${accessible.length} active drives', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _StatChip(icon: Icons.business, label: 'Companies', value: '${accessible.length}')),
                    const SizedBox(width: 8),
                    Expanded(child: _StatChip(icon: Icons.event_available, label: 'Open', value: '${accessible.length}')),
                  ]),
                ]),
              ),
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: filters.map((filter) {
                    final isSelected = _selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(filter),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _selectedFilter = filter),
                        selectedColor: const Color(0xFFEAB308),
                        backgroundColor: Colors.grey.shade100,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.black : Colors.grey.shade700,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.work_off, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text('No placement drives found', style: TextStyle(color: Colors.grey.shade500)),
                        ]),
                      )
                    : Consumer(builder: (context, ref, _) {
                        final overviewAsync = ref.watch(placementOverviewProvider);
                        final metricsAsync = ref.watch(placementMetricsProvider);
                        final items = (overviewAsync.asData?.value['items'] as List<dynamic>? ?? [])
                            .cast<Map<String, dynamic>>();
                        final statusByDrive = {
                          for (final item in items)
                            if (item['driveId'] != null) (item['driveId'] as num).toInt(): item['status']?.toString() ?? 'OPEN',
                        };
                        final metrics = metricsAsync.asData?.value ?? <String, double>{};
                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final drive = filtered[index];
                            final eligible = drive.isEligibleFor(metrics);
                            return _DriveCard(
                              drive: drive,
                              status: statusByDrive[drive.id] ?? 'OPEN',
                              isEligible: eligible,
                              onApply: () => _applyAndOpenLink(ref, drive),
                              onScheduleSlot: () => _showSlotPicker(ref, drive),
                            );
                          },
                        );
                      }),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _applyAndOpenLink(WidgetRef ref, PlacementDriveModel drive) async {
    await ref.read(apiServiceProvider).applyToPlacementDrive(drive.id);
    ref.invalidate(placementOverviewProvider);
    final link = drive.applyLink;
    if (link == null || link.isEmpty) return;
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InAppBrowserScreen(url: link, title: '${drive.companyName} - Apply'),
      ),
    );
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

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(mySlot != null ? 'Your Interview Slot' : 'Available Interview Slots',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(drive.companyName, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 16),
            if (mySlot != null)
              _BookedSlotSummary(slot: mySlot)
            else if (available.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No open slots right now. Check back later.', style: TextStyle(color: Colors.grey.shade500))),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: available.length,
                  itemBuilder: (context, index) {
                    final slot = available[index];
                    return ListTile(
                      leading: const Icon(Icons.schedule, color: Color(0xFF0F172A)),
                      title: Text((slot['slotTime'] ?? '').toString().replaceFirst('T', '  ')),
                      subtitle: Text(slot['location'] ?? ''),
                      trailing: ElevatedButton(
                        onPressed: () async {
                          final success = await api.bookInterviewSlot(slot['id'] as int);
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(success ? 'Interview slot booked!' : 'Failed to book slot. Try another.')),
                          );
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEAB308), foregroundColor: const Color(0xFF0F172A)),
                        child: const Text('Book'),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The confirmed slot a student already holds for a drive -- shown instead of
/// the booking list so they can't pick a second one out from under it.
class _BookedSlotSummary extends StatelessWidget {
  final Map<String, dynamic> slot;
  const _BookedSlotSummary({required this.slot});

  @override
  Widget build(BuildContext context) {
    final location = (slot['location'] ?? '').toString();
    final notes = (slot['notes'] ?? '').toString();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        border: Border.all(color: const Color(0xFF6EE7B7)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.check_circle, color: Color(0xFF059669), size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Your slot is confirmed', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF065F46))),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Icon(Icons.schedule, size: 16, color: Colors.grey.shade700),
            const SizedBox(width: 8),
            Text((slot['slotTime'] ?? '').toString().replaceFirst('T', '  '), style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
          if (location.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.location_on, size: 16, color: Colors.grey.shade700),
              const SizedBox(width: 8),
              Expanded(child: Text(location)),
            ]),
          ],
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(notes, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
          const SizedBox(height: 12),
          Text('Contact your institute if you need to reschedule.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatChip({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(icon, color: const Color(0xFFEAB308), size: 18),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          Text(label, style: TextStyle(color: Colors.white70, fontSize: 10)),
        ]),
      ]),
    );
  }
}

class _DriveCard extends StatelessWidget {
  final PlacementDriveModel drive;
  final String status;
  final bool isEligible;
  final VoidCallback onApply;
  final VoidCallback onScheduleSlot;

  const _DriveCard({
    required this.drive,
    required this.status,
    required this.isEligible,
    required this.onApply,
    required this.onScheduleSlot,
  });

  Color get _statusColor {
    switch (status) {
      case 'APPLIED':
        return Colors.orange;
      case 'SELECTED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String get _statusLabel {
    switch (status) {
      case 'APPLIED':
        return 'Applied';
      case 'SELECTED':
        return 'Selected';
      case 'REJECTED':
        return 'Rejected';
      default:
        return 'Open';
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF0F172A);
    final secondaryColor = const Color(0xFFEAB308);
    final logoColor = _getLogoColor(drive.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: logoColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(drive.logoInitial, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(drive.companyName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 2),
                Text(drive.role, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                const SizedBox(height: 4),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: secondaryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.savings, size: 12, color: Color(0xFFB45309)),
                      const SizedBox(width: 4),
                      Text(drive.packageDisplay, style: const TextStyle(fontSize: 11, color: Color(0xFFB45309), fontWeight: FontWeight.bold)),
                    ]),
                  ),
                  if (drive.location != null && drive.location!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.location_on, size: 12, color: Colors.blue),
                        const SizedBox(width: 2),
                        Text(drive.location!, style: const TextStyle(fontSize: 11, color: Colors.blue)),
                      ]),
                    ),
                  ],
                ]),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: secondaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  drive.category,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB45309),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _statusLabel,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _statusColor),
                ),
              ),
            ]),
          ]),
          if (drive.eligibility != null && drive.eligibility!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(Icons.check_circle_outline, size: 14, color: Colors.grey),
                  SizedBox(width: 6),
                  Text('Eligibility', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ]),
                const SizedBox(height: 4),
                Text(drive.eligibility!, style: TextStyle(fontSize: 11, color: Colors.grey.shade700, height: 1.4)),
              ]),
            ),
          ],
          if (drive.description != null && drive.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(drive.description!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4)),
          ],
          const SizedBox(height: 12),
          Row(children: [
            Icon(Icons.event, size: 14, color: Colors.grey.shade500),
            const SizedBox(width: 6),
            Text('Deadline: ', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            Text(drive.formattedDeadline, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const Spacer(),
            if (drive.isInternal && status != 'SELECTED' && isEligible)
              OutlinedButton.icon(
                onPressed: onScheduleSlot,
                icon: const Icon(Icons.event_available, size: 16),
                label: const Text('Schedule my slot'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryColor,
                  side: BorderSide(color: primaryColor),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                ),
              ),
            const SizedBox(width: 8),
            if (!isEligible && status != 'APPLIED' && status != 'SELECTED')
              ElevatedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.block, size: 16),
                label: const Text('Not eligible'),
                style: ElevatedButton.styleFrom(
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade600,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: status == 'SELECTED' ? null : onApply,
                icon: Icon(status == 'APPLIED' ? Icons.check_circle : Icons.open_in_browser, size: 16),
                label: Text(status == 'OPEN' || status == 'REJECTED' ? 'Apply' : (status == 'APPLIED' ? 'Applied' : 'Selected')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: secondaryColor,
                  foregroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                ),
              ),
          ]),
        ]),
      ),
    );
  }

  Color _getLogoColor(int id) {
    const colors = [
      Color(0xFF4285F4),
      Color(0xFF00A4EF),
      Color(0xFF0F9D58),
      Color(0xFF2078F4),
      Color(0xFF2874F0),
      Color(0xFFE82127),
    ];
    return colors[id % colors.length];
  }
}

extension on PlacementDriveModel {
  bool isAccessible(Set<int>? activePlanIds) {
    if (planId == null) return true;
    if (activePlanIds == null) return false;
    return activePlanIds.contains(planId);
  }
}