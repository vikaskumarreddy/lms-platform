import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/common_header.dart';

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  final ApiService _api = ApiService();
  bool _loading = true;
  List<_PaymentItem> _payments = [];

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    setState(() => _loading = true);
    final raw = await _api.getPaymentHistory();
    if (!mounted) return;

    final payments = raw.map((entry) {
      final amountPaise = (entry['amount'] as num?)?.toDouble() ?? 0;
      return _PaymentItem(
        method: (entry['method'] as String?) ?? 'ONLINE',
        status: (entry['status'] as String?) ?? 'UNKNOWN',
        amount: amountPaise / 100.0,
        currency: (entry['currency'] as String?) ?? 'INR',
        date: DateTime.tryParse((entry['date'] as String?) ?? ''),
      );
    }).toList();

    setState(() {
      _payments = payments;
      _loading = false;
    });
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
      case 'CAPTURED':
        return Colors.green;
      case 'PENDING':
      case 'AUTHORIZED':
        return Colors.orange;
      case 'FAILED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF0F172A);

    return Scaffold(
      appBar: const CommonHeader(title: 'Payment History'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _payments.isEmpty
              ? Center(
                  child: Text(
                    'No payment history yet.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPayments,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text('Payment History',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold, color: primaryColor)),
                      const SizedBox(height: 16),
                      for (final payment in _payments)
                        _buildPaymentItem(payment),
                    ],
                  ),
                ),
    );
  }

  Widget _buildPaymentItem(_PaymentItem payment) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.payment, color: Colors.white)),
        title: Text(
          payment.method == 'CASH' ? 'Cash Payment' : 'Online Payment',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(_formatDate(payment.date), style: TextStyle(color: Colors.grey.shade600)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${payment.currency} ${payment.amount.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(payment.status, style: TextStyle(color: _statusColor(payment.status), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _PaymentItem {
  final String method;
  final String status;
  final double amount;
  final String currency;
  final DateTime? date;

  _PaymentItem({
    required this.method,
    required this.status,
    required this.amount,
    required this.currency,
    required this.date,
  });
}
