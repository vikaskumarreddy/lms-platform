import 'package:flutter/material.dart';
import '../../../core/widgets/common_header.dart';

class PaymentScreen extends StatefulWidget {
  final int planId;
  const PaymentScreen({super.key, required this.planId});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _selectedMethod = 'card';
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _cardHolderController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF0F172A);
    final secondaryColor = const Color(0xFFEAB308);

    return Scaffold(
      appBar: const CommonHeader(showBackButton: true, title: 'Payment'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: primaryColor,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Premium Plan', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
                    const SizedBox(height: 8),
                    Text('₹1,999', style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('per month', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Payment Method', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: primaryColor)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PaymentMethodCard(
                    icon: Icons.credit_card,
                    title: 'Card',
                    isSelected: _selectedMethod == 'card',
                    onTap: () => setState(() => _selectedMethod = 'card'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PaymentMethodCard(
                    icon: Icons.account_balance_wallet,
                    title: 'Wallet',
                    isSelected: _selectedMethod == 'wallet',
                    onTap: () => setState(() => _selectedMethod = 'wallet'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PaymentMethodCard(
                    icon: Icons.qr_code,
                    title: 'UPI',
                    isSelected: _selectedMethod == 'upi',
                    onTap: () => setState(() => _selectedMethod = 'upi'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_selectedMethod == 'card') ...[
              Text('Card Details', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: primaryColor)),
              const SizedBox(height: 12),
              TextField(
                controller: _cardNumberController,
                decoration: InputDecoration(
                  hintText: '1234 5678 9012 3456',
                  prefixIcon: const Icon(Icons.credit_card, size: 20),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _cardHolderController,
                decoration: InputDecoration(
                  hintText: 'Card Holder Name',
                  prefixIcon: const Icon(Icons.person, size: 20),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _expiryController,
                      decoration: InputDecoration(
                        hintText: 'MM/YY',
                        prefixIcon: const Icon(Icons.calendar_today, size: 20),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _cvvController,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: 'CVV',
                        prefixIcon: const Icon(Icons.lock, size: 20),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (_selectedMethod == 'wallet') ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.account_balance_wallet, color: secondaryColor),
                      const SizedBox(width: 12),
                      const Expanded(child: Text('Pay using Wallet Balance')),
                      Radio(value: 1, groupValue: 1, onChanged: (v) {}),
                    ],
                  ),
                ),
              ),
              Text('Available Balance: ₹5,000', style: TextStyle(color: Colors.grey.shade600)),
            ],
            if (_selectedMethod == 'upi') ...[
              TextField(
                decoration: InputDecoration(
                  hintText: 'Enter UPI ID',
                  prefixIcon: const Icon(Icons.qr_code, size: 20),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Payment processing...')),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor, padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('Pay ₹1,999', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.lock, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text('Secure payment powered by Stripe', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  const _PaymentMethodCard({required this.icon, required this.title, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEAB308).withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? const Color(0xFFEAB308) : Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? const Color(0xFFEAB308) : Colors.grey.shade600),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? const Color(0xFFEAB308) : Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}