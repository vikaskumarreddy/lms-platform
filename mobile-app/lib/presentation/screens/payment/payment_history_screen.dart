import 'package:flutter/material.dart';
import '../../../core/widgets/common_header.dart';

class PaymentHistoryScreen extends StatelessWidget {
  const PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF0F172A);

    return Scaffold(
      appBar: const CommonHeader(title: 'Payment History'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Payment History',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold, color: primaryColor)),
          const SizedBox(height: 16),
          _buildPaymentItem(
              context,
              'Java Full Stack Course',
              'Completed',
              '\$199.99',
              'Jul 15, 2024',
              Colors.green),
          _buildPaymentItem(
              context,
              'Premium Subscription',
              'Completed',
              '\$49.99',
              'Jun 01, 2024',
              Colors.green),
          _buildPaymentItem(
              context,
              'Certification Exam',
              'Pending',
              '\$29.99',
              'May 20, 2024',
              Colors.orange),
        ],
      ),
    );
  }

  Widget _buildPaymentItem(
    BuildContext context,
    String title,
    String status,
    String amount,
    String date,
    Color statusColor,
  ) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.payment, color: Colors.white)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(date, style: TextStyle(color: Colors.grey.shade600)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(amount, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(status, style: TextStyle(color: statusColor, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
