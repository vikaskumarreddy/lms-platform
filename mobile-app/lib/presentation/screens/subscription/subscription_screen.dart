import 'package:flutter/material.dart';
import '../../../core/widgets/common_header.dart';
import '../../../data/models/subscription_plan.dart';
import '../../../core/services/api_service.dart';

const Color _kInk = Color(0xFF0F172A);
const Color _kAccent = Color(0xFFEAB308);

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final ApiService _api = ApiService();

  List<SubscriptionPlanModel> _plans = [];
  bool _loading = true;
  bool _submitting = false;

  /// The student's actual plan, read from their profile rather than guessed.
  int? _currentPlanId;
  String? _currentPlanName;

  /// The open request, if any. While one exists every other plan is locked so the
  /// student cannot queue up several asks the admin then has to untangle.
  Map<String, dynamic>? _pendingRequest;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final plans = await _api.getSubscriptionPlans();
    final profile = await _api.getUserProfile();
    final requests = await _api.getMyPlanRequests();

    if (!mounted) return;
    setState(() {
      _plans = plans.where((p) => p.isActive).toList();
      _currentPlanId = (profile?['planId'] as num?)?.toInt();
      _currentPlanName = profile?['planName'] as String?;
      _pendingRequest = requests.cast<Map<String, dynamic>?>().firstWhere(
            (r) => r?['status'] == 'PENDING',
            orElse: () => null,
          );
      _loading = false;
    });
  }

  Color _parseColor(String colorHex) {
    if (colorHex.isEmpty) return _kInk;
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return _kInk;
    }
  }

  bool _isCurrent(SubscriptionPlanModel plan) =>
      _currentPlanId != null && plan.id == _currentPlanId;

  bool _isPendingPlan(SubscriptionPlanModel plan) =>
      _pendingRequest != null &&
      (_pendingRequest!['requestedPlanId'] as num?)?.toInt() == plan.id;

  // ------------------------------------------------------------------- actions

  Future<void> _requestUpgrade(SubscriptionPlanModel plan) async {
    final noteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Request ${plan.name}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your institute will review this request. You will be notified once '
              'it is approved — your plan does not change until then.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              maxLines: 2,
              maxLength: 300,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'Anything the institute should know',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _kInk, foregroundColor: Colors.white),
            child: const Text('Send request'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _submitting = true);
    final error = await _api.requestPlanUpgrade(plan.id, note: noteController.text.trim());
    if (!mounted) return;
    setState(() => _submitting = false);

    if (error != null) {
      _snack(error, Colors.red);
      return;
    }
    _snack('Request sent. Your institute will review it shortly.', Colors.green);
    _load();
  }

  void _snack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  // --------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonHeader(title: 'Subscription'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _plans.isEmpty
              ? const Center(child: Text('No subscription plans available'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: Column(
                    children: [
                      _currentPlanBanner(),
                      if (_pendingRequest != null) _pendingBanner(),
                      Expanded(
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: _plans.length,
                          itemBuilder: (context, index) => _planCard(_plans[index]),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _currentPlanBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_kInk, _kInk.withOpacity(0.8)]),
      ),
      child: Column(
        children: [
          const Text('Current Plan',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            _currentPlanName ?? 'No plan assigned',
            style: const TextStyle(color: _kAccent, fontWeight: FontWeight.bold, fontSize: 26),
          ),
          if (_currentPlanName == null) ...[
            const SizedBox(height: 4),
            const Text('Ask your institute to assign one, or request an upgrade below.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _pendingBanner() {
    final planName = _pendingRequest!['requestedPlanName'] ?? 'a new plan';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        border: Border.all(color: const Color(0xFFFCD34D)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_top, color: Color(0xFF92400E), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your request for $planName is awaiting approval from your institute.',
              style: const TextStyle(fontSize: 13, color: Color(0xFF78350F), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _planCard(SubscriptionPlanModel plan) {
    final planColor = _parseColor(plan.color);
    final isCurrent = _isCurrent(plan);
    final isPending = _isPendingPlan(plan);
    // Any open request blocks every other plan, not just the one asked for.
    final blocked = _pendingRequest != null && !isPending;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isCurrent ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isCurrent ? BorderSide(color: planColor, width: 2) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(plan.name,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: planColor)),
                ),
                if (isCurrent)
                  _tag('CURRENT', planColor)
                else if (plan.isPopular)
                  _tag('POPULAR', _kAccent),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('₹${plan.price.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: planColor)),
                Text(plan.period, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            ...plan.features.map((feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle, size: 20, color: Colors.green),
                      const SizedBox(width: 12),
                      Expanded(child: Text(feature, style: const TextStyle(fontSize: 14))),
                    ],
                  ),
                )),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (isCurrent || isPending || blocked || _submitting)
                    ? null
                    : () => _requestUpgrade(plan),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCurrent ? planColor : _kAccent,
                  foregroundColor: isCurrent ? Colors.white : Colors.black,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  isCurrent
                      ? 'Current Plan'
                      : isPending
                          ? 'Awaiting approval'
                          : blocked
                              ? 'Request pending on another plan'
                              : 'Request Upgrade',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Text(label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
    );
  }
}
