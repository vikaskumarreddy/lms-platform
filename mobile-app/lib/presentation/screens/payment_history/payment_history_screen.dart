import 'package:flutter/material.dart';
import '../../../core/widgets/common_header.dart';

class PaymentHistoryScreen extends StatelessWidget {
  const PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonHeader(title: 'Payment History'),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Color(0xFFEAB308)),
            const SizedBox(height: 16),
            Text('PaymentHistoryScreen', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text('Coming Soon', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

