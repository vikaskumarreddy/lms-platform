import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/utils/certificate_pdf_generator.dart';
import '../../../core/widgets/common_header.dart';
import '../../../core/config/app_config.dart';

class CertificatesScreen extends ConsumerWidget {
  const CertificatesScreen({super.key});

  static const _bgDark = Color(0xFF071D43);
  static const _cyan = Color(0xFF27D9D3);
  static const _gold = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final certificatesAsync = ref.watch(certificatesProvider);

    return CommonHeaderScaffold(
      subtitle: 'Certificates',
      backgroundColor: _bgDark,
      body: certificatesAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _cyan)),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: Colors.white38),
              const SizedBox(height: 12),
              const Text('Failed to load certificates',
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(certificatesProvider),
                child: const Text('Retry', style: TextStyle(color: _cyan)),
              ),
            ],
          ),
        ),
        data: (certificates) {
          if (certificates.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _gold.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.workspace_premium_rounded,
                        size: 64, color: _gold),
                  ),
                  const SizedBox(height: 16),
                  const Text('No certificates earned yet',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text('Complete all course modules to unlock your certificate',
                      style: TextStyle(color: Colors.white54, fontSize: 13)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
            itemCount: certificates.length,
            itemBuilder: (context, index) => _CertificateCard(
              cert: certificates[index],
            ),
          );
        },
      ),
    );
  }
}

class _CertificateCard extends StatelessWidget {
  final Map<String, dynamic> cert;
  const _CertificateCard({required this.cert});

  static const _cardDark = Color(0xFF0C2B64);
  static const _cyan = Color(0xFF27D9D3);
  static const _gold = Color(0xFFF59E0B);

  Future<void> _view(BuildContext context) async {
    final doc = await _buildDoc(context);
    final bytes = await doc.save();
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _CertificatePreviewScreen(pdfBytes: bytes),
      ),
    );
  }

  Future<void> _addToLinkedIn(BuildContext context) async {
    final courseName = cert['courseName'] ?? 'Certification';
    final instituteName = cert['instituteName'] ?? 'Institute';
    final credentialId = cert['credentialId'] ?? '';
    final tenantSlug = cert['tenantSlug'] ?? cert['organizationSlug'];
    final verifyUrl = AppConfig.certificateVerifyUrl(credentialId, tenantSlug);
    final uri = Uri.parse(
      'https://www.linkedin.com/profile/add?startTask=CERTIFICATION_NAME'
      '&name=${Uri.encodeComponent(courseName)}'
      '&organizationName=${Uri.encodeComponent(instituteName)}'
      '&certUrl=${Uri.encodeComponent(verifyUrl)}'
      '&certId=${Uri.encodeComponent(credentialId)}',
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open LinkedIn browser')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening LinkedIn: $e')),
        );
      }
    }
  }

  Future<void> _download(BuildContext context) async {
    final doc = await _buildDoc(context);
    final bytes = await doc.save();
    final fileName =
        'Certificate_${(cert['courseName'] ?? 'Course').toString().replaceAll(' ', '_')}.pdf';
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }

  Future<pw.Document> _buildDoc(BuildContext context) {
    final credentialId = cert['credentialId'] ?? '';
    return CertificatePdfGenerator.generate(
      accentColor: _gold.value,
      primaryColor: const Color(0xFF0C2B64).value,
      studentName: cert['studentName'] ?? '',
      studentEmail: cert['studentEmail'] ?? '',
      instituteName: cert['instituteName'] ?? '',
      courseName: cert['courseName'] ?? '',
      duration: cert['duration'],
      credentialId: credentialId,
      issueDate: cert['issueDate'] ?? '',
      verifyUrl: AppConfig.certificateVerifyUrl(credentialId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final courseName = cert['courseName'] ?? 'Certified Course';
    final instituteName = cert['instituteName'] ?? 'Axisora LMS';
    final credentialId = cert['credentialId'] ?? 'N/A';
    final issueDate = cert['issueDate'] ?? 'N/A';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _cardDark.withOpacity(0.70),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF1E5BB0).withOpacity(0.50)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _gold.withOpacity(0.20),
                    shape: BoxShape.circle,
                    border: Border.all(color: _gold.withOpacity(0.50)),
                    boxShadow: [
                      BoxShadow(
                        color: _gold.withOpacity(0.25),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.workspace_premium_rounded,
                      color: _gold, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        courseName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16.5,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        instituteName,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF93C5FD),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Credential ID',
                        style: TextStyle(fontSize: 11, color: Colors.white54)),
                    const SizedBox(height: 2),
                    Text(
                      credentialId,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Issued Date',
                        style: TextStyle(fontSize: 11, color: Colors.white54)),
                    const SizedBox(height: 2),
                    Text(
                      issueDate,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _view(context),
                    icon: const Icon(Icons.visibility_rounded, size: 17),
                    label: const Text('View PDF'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _cyan,
                      side: BorderSide(color: _cyan.withOpacity(0.60)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _download(context),
                    icon: const Icon(Icons.download_rounded, size: 17),
                    label: const Text('Download'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _cyan,
                      foregroundColor: const Color(0xFF041838),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _addToLinkedIn(context),
                icon: const Icon(Icons.share_rounded, size: 16),
                label: const Text('Add to LinkedIn Profile'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A66C2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CertificatePreviewScreen extends StatelessWidget {
  final Uint8List pdfBytes;
  const _CertificatePreviewScreen({required this.pdfBytes});

  @override
  Widget build(BuildContext context) {
    return CommonHeaderScaffold(
      subtitle: 'Certificate Preview',
      showBackButton: true,
      backgroundColor: const Color(0xFF071D43),
      body: PdfPreview(
        build: (format) => pdfBytes,
        allowPrinting: true,
        allowSharing: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        pdfFileName: 'certificate.pdf',
      ),
    );
  }
}
