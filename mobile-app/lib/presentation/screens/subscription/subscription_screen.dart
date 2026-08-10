import 'package:flutter/material.dart';
import '../../../core/widgets/common_header.dart';
import '../../../data/models/subscription_plan.dart';
import '../../../core/services/api_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  List<SubscriptionPlanModel> _plans = [];
  bool _loading = true;
  String? _currentPlanName;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    final api = ApiService();
    final plans = await api.getSubscriptionPlans();
    final activePlans = plans.where((p) => p.isActive).toList();
    setState(() {
      _plans = activePlans;
      // Default to the popular plan, or the first plan, to match previous UI
      final popular = activePlans.where((p) => p.isPopular).firstOrNull;
      _currentPlanName = popular?.name ?? (activePlans.isNotEmpty ? activePlans.first.name : null);
      _loading = false;
    });
  }

  Color _parseColor(String colorHex) {
    if (colorHex.isEmpty) return const Color(0xFF0F172A);
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF0F172A);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonHeader(title: 'Subscription'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _plans.isEmpty
              ? const Center(child: Text('No subscription plans available'))
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [const Color(0xFF0F172A), const Color(0xFF0F172A).withOpacity(0.8)]),
                      ),
                      child: Column(
                        children: [
                          Text('Current Plan', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(_currentPlanName ?? 'Premium', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: const Color(0xFFEAB308), fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Renews on 15 Feb 2026', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _plans.length,
                        itemBuilder: (context, index) {
                          final plan = _plans[index];
                          final planColor = _parseColor(plan.color);
                          final isSelected = _currentPlanName == plan.name;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: isSelected ? 4 : 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: isSelected ? BorderSide(color: planColor, width: 2) : BorderSide.none,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(plan.name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: planColor)),
                                      if (plan.isPopular)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                          decoration: BoxDecoration(color: const Color(0xFFEAB308), borderRadius: BorderRadius.circular(12)),
                                          child: const Text('POPULAR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('₹${plan.price.toStringAsFixed(0)}', style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold, color: planColor)),
                                      Text(plan.period, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  const Divider(),
                                  const SizedBox(height: 12),
                                  ...plan.features.map((feature) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        Icon(Icons.check_circle, size: 20, color: Colors.green),
                                        const SizedBox(width: 12),
                                        Expanded(child: Text(feature, style: const TextStyle(fontSize: 14))),
                                      ],
                                    ),
                                  )),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () {},
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isSelected ? planColor : Colors.grey.shade300,
                                        foregroundColor: isSelected ? Colors.white : Colors.grey.shade700,
                                      ),
                                      child: Text(isSelected ? 'Current Plan' : 'Upgrade Now'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}