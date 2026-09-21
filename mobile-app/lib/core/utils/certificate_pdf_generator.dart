import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Generates a certificate PDF document using data configured by the admin
/// (institute name, course name, duration) combined with the currently
/// logged-in student's own name/email -- never any other user's identity.
class CertificatePdfGenerator {
  static Future<pw.Document> generate({
    required String studentName,
    required String studentEmail,
    required String instituteName,
    required String courseName,
    String? duration,
    required String credentialId,
    required String issueDate, int accentColor = 0xFFEAB308, int primaryColor = 0xFF0F172A,
  }) async {
    final doc = pw.Document();
    final gold = PdfColor.fromInt(accentColor);
    final navy = PdfColor.fromInt(primaryColor);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: navy, width: 6),
            ),
            margin: const pw.EdgeInsets.all(16),
            padding: const pw.EdgeInsets.all(36),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text('CERTIFICATE OF COMPLETION',
                    style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: navy, letterSpacing: 2)),
                pw.SizedBox(height: 4),
                pw.Container(width: 120, height: 3, color: gold),
                pw.SizedBox(height: 28),
                pw.Text('This certificate is proudly presented to', style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
                pw.SizedBox(height: 12),
                pw.Text(studentName, style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold, color: navy)),
                pw.SizedBox(height: 4),
                pw.Text(studentEmail, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
                pw.SizedBox(height: 24),
                pw.Text(
                  'for successfully completing the course',
                  style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 8),
                pw.Text(courseName, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: gold)),
                if (duration != null && duration.isNotEmpty) ...[
                  pw.SizedBox(height: 8),
                  pw.Text('Duration: $duration', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                ],
                pw.SizedBox(height: 36),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text('Credential ID', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                      pw.Text(credentialId, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    ]),
                    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
                      pw.Text(instituteName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: navy)),
                      pw.SizedBox(height: 2),
                      pw.Text('Issuing Institute', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                    ]),
                    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                      pw.Text('Issue Date', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                      pw.Text(issueDate, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    ]),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
    return doc;
  }
}
