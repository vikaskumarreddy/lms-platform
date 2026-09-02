import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/routes.dart';
import '../../../core/widgets/common_header.dart';

/// Real gateway checkout. The amount is NOT typed in by anyone: the backend
/// derives it from the student's subscription plan price, and this screen just
/// reads it back from /payments/status. Tapping Pay creates a gateway order and
/// opens the vendor's hosted checkout page in an in-app webview; while it is
/// open the app polls /payments/order-status and, once the backend captures the
/// payment (via the gateway's browser redirect), the student is sent to the
/// dashboard. No local amount entry, no mock UI.
class PaymentScreen extends StatefulWidget {
  final int planId;
  const PaymentScreen({super.key, required this.planId});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _status;
  bool _loading = true;
  bool _paying = false;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final status = await _api.getPaymentStatus();
    if (!mounted) return;
    setState(() {
      _status = status;
      _loading = false;
      _success = status != null && status['paymentStatus'] == 'COMPLETED';
    });
  }

  /// Rupee amount for display — /status returns amountDue in rupees.
  double get _amount {
    final v = _status?['amountDue'];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  String get _gateway =>
      (_status?['gateway'] ?? 'RAZORPAY').toString().toUpperCase();

  String _gatewayLabel() => _gateway == 'PAYU'
      ? 'PayU'
      : _gateway == 'CASHFREE'
          ? 'Cashfree'
          : 'Razorpay';

  Future<void> _startPayment() async {
    setState(() => _paying = true);
    Timer? pollTimer;
    try {
      final order = await _api.createPaymentOrder();
      if (!mounted) return;
      if (order == null || order['orderId'] == null) {
        throw Exception(order?['error'] ?? 'Could not start payment');
      }
      final orderId = order['orderId'].toString();
      final html = _buildCheckoutHtml(order, orderId);

      // Open the vendor checkout, then poll for capture while it is open.
      bool captured = false;
      await showModalBottomSheet(
        context: context,
        isDismissible: false,
        enableDrag: false,
        useSafeArea: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (sheetContext) {
          Future<void> poll() async {
            if (captured || !sheetContext.mounted) return;
            if (await _api.isOrderPaid(orderId)) {
              captured = true;
              pollTimer?.cancel();
              if (sheetContext.mounted) Navigator.of(sheetContext).pop();
              if (mounted) {
                setState(() => _success = true);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Payment successful! Welcome aboard'),
                  backgroundColor: Colors.green,
                ));
                context.go(AppRoutes.home);
              }
            }
          }

          pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => poll());
          return Scaffold(
            appBar: AppBar(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              title: const Text('Secure Checkout',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(sheetContext).pop(),
              ),
            ),
            body: InAppWebView(
              initialData: InAppWebViewInitialData(data: html,
                  mimeType: 'text/html', encoding: 'utf-8'),
              initialSettings: InAppWebViewSettings(javaScriptEnabled: true),
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ));
      }
    }
    pollTimer?.cancel();
    if (mounted) setState(() => _paying = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: const CommonHeader(title: 'Payment'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _success
              ? _successView()
              : RefreshIndicator(
                  onRefresh: _loadStatus,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${_gatewayLabel()} Secure Checkout',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 13)),
                            const SizedBox(height: 8),
                            Text('\u20B9${_amount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 34,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            const Text('Subscription enrollment fee',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Your enrollment is one payment away',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: Color(0xFF0F172A))),
                            SizedBox(height: 6),
                            Text(
                              'Tapping Pay opens the gateway secure checkout. Cards, UPI, '
                              'netbanking and wallets are supported. Once the payment is '
                              'verified you will be taken to your dashboard automatically.',
                              style: TextStyle(
                                  color: Color(0xFF475569),
                                  fontSize: 13,
                                  height: 1.4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _paying ? null : _startPayment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _paying
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.4))
                              : const Text('Pay Securely',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Center(
                        child: Text(
                          'Payments are verified server-side before your '
                          'enrollment is activated.',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _successView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7), shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded,
                color: Color(0xFF16A34A), size: 48),
          ),
          const SizedBox(height: 16),
          const Text('Payment successful!',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A))),
          const SizedBox(height: 6),
          const Text('Your enrollment is confirmed.',
              style: TextStyle(color: Color(0xFF475569))),
        ],
      ),
    );
  }


  /// Vendor-agnostic hosted-checkout HTML. For PayU it auto-submits the signed
  /// request to PayU's endpoint; for Razorpay it loads Standard Checkout; for
  /// Cashfree it opens the hosted payment page. The gateway's own redirect back
  /// to /api/payments/callback/... completes the capture server-side.
  String _buildCheckoutHtml(Map<String, dynamic> order, String orderId) {
    String esc(Object? s) => (s?.toString() ?? '')
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');

    if (_gateway == 'PAYU') {
      final fields = <String>[];
      order.forEach((k, v) {
        if (v != null && v.toString().isNotEmpty) {
          fields.add('<input type="hidden" name="${esc(k)}" value="${esc(v)}">');
        }
      });
      return '<!DOCTYPE html><html><body onload="document.forms[0].submit()">'
          '<form method="POST" action="${esc(order['actionUrl'])}">$fields</form>'
          '<p style="font-family:sans-serif">Redirecting to PayU...</p></body></html>';
    }

    if (_gateway == 'CASHFREE') {
      final sessionId = order['paymentSessionId']?.toString() ?? '';
      final mode = order['mode']?.toString() ?? 'TEST';
      return '<!DOCTYPE html><html><head>'
          '<meta name="viewport" content="width=device-width, initial-scale=1">'
          '<script src="https://sdk.cashfree.com/js/v3/cashfree.js"></script>'
          '</head><body style="margin:0">'
          '<div id="drop_in_container" style="height:100vh"></div>'
          '<script>'
          'const cashfree = Cashfree({mode: "${esc(mode)}"});'
          'cashfree.checkout({paymentSessionId: "${esc(sessionId)}", redirectTarget: "_self"});'
          '</script></body></html>';
    }

    // RAZORPAY — Standard Checkout; the server-side callback verifies the
    // signature and marks the payment captured.
    final orderJson = json.encode(order);
    return '<!DOCTYPE html><html><head>'
        '<meta name="viewport" content="width=device-width, initial-scale=1">'
        '<script src="https://checkout.razorpay.com/v1/checkout.js"></script>'
        '</head><body style="margin:0">'
        '<script>'
        'var order = $orderJson;'
        'var rzp = new Razorpay({'
        '  key: order.keyId,'
        '  order_id: order.orderId,'
        '  amount: order.amount,'
        '  currency: order.currency,'
        '  name: "Course Enrollment",'
        '  description: "Subscription fee",'
        '  theme: {color: "#0F172A"},'
        '  handler: function(resp) {'
        '    var qs = "?razorpay_payment_id=" + encodeURIComponent(resp.razorpay_payment_id)'
        '      + "&razorpay_order_id=" + encodeURIComponent(resp.razorpay_order_id)'
        '      + "&razorpay_signature=" + encodeURIComponent(resp.razorpay_signature);'
        '    window.location.href = "${esc(ApiService.baseUrl)}/payments/callback/razorpay/$orderId" + qs;'
        '  }'
        '});'
        'rzp.open();'
        '</script></body></html>';
  }
}

