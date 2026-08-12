import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/utils/certificate_pdf_generator.dart';
import '../../../core/widgets/common_header.dart';

final certificatesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getCertificates();
});

class CertificatesScreen extends ConsumerWidget {
  const CertificatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final certificatesAsync = ref.watch(certificatesProvider);
    const primaryColor = Color(0xFF0F172A);
    const secondaryColor = Color(0xFFEAB308);

    return Scaffold(
      appBar: const CommonHeader(title: 'Certificates'),
      body: certificatesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text('Failed to load certificates', style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              TextButton(onPressed: () => ref.invalidate(certificatesProvider), child: const Text('Retry')),
            ],
          ),
        ),
        data: (certificates) {
          if (certificates.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.workspace_premium_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('No certificates yet', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('Complete a course to earn your certificate', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: certificates.length,
            itemBuilder: (context, index) => _CertificateCard(
              cert: certificates[index],
              primaryColor: primaryColor,
              secondaryColor: secondaryColor,
            ),
          );
        },
      ),
    );
  }
}

class _CertificateCard extends StatelessWidget {
  final Map<String, dynamic> cert;
  final Color primaryColor;
  final Color secondaryColor;
  const _CertificateCard({required this.cert, required this.primaryColor, required this.secondaryColor});

  Future<void> _view(BuildContext context) async {
    final doc = await _buildDoc();
    final bytes = await doc.save();
    if (!context.mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => _CertificatePreviewScreen(pdfBytes: bytes)));
  }

  Future<void> _download(BuildContext context) async {
    final doc = await _buildDoc();
    final bytes = await doc.save();
    final fileName = 'Certificate_${(cert['courseName'] ?? 'Course').toString().replaceAll(' ', '_')}.pdf';
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }

  Future<pw.Document> _buildDoc() {
    return CertificatePdfGenerator.generate(
      studentName: cert['studentName'] ?? '',
      studentEmail: cert['studentEmail'] ?? '',
      instituteName: cert['instituteName'] ?? '',
      courseName: cert['courseName'] ?? '',
      duration: cert['duration'],
      credentialId: cert['credentialId'] ?? '',
      issueDate: cert['issueDate'] ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: secondaryColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.workspace_premium, color: secondaryColor, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(cert['courseName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 2),
                Text(cert['instituteName'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Credential ID', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              Text(cert['credentialId'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('Issued', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              Text(cert['issueDate'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            ]),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _view(context),
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('View'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _download(context),
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Download'),
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _CertificatePreviewScreen extends StatelessWidget {
  final Uint8List pdfBytes;
  const _CertificatePreviewScreen({required this.pdfBytes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonHeader(showBackButton: true, title: 'Certificate Preview'),
      body: PdfPreview(
        build: (format) async => pdfBytes,
        allowSharing: true,
        allowPrinting: true,
        canChangePageFormat: false,
        canChangeOrientation: false,
      ),
    );
  }
}
