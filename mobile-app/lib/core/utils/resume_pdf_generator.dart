import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

enum ResumeTemplate { classic, modern, minimal }

/// A named group of skills (e.g. "Programming Languages" -> [Java, Python]).
class SkillCategory {
  final String name;
  final List<String> skills;
  SkillCategory(this.name, this.skills);
}

/// A single work experience entry with a description and bullet points.
class ExperienceItem {
  final String role;
  final String company;
  final String location;
  final String startDate;
  final String endDate;
  final bool current;
  final String description;
  final List<String> points;

  ExperienceItem({
    this.role = '',
    this.company = '',
    this.location = '',
    this.startDate = '',
    this.endDate = '',
    this.current = false,
    this.description = '',
    this.points = const [],
  });

  String get dateRange {
    final end = current ? 'Present' : endDate;
    return [startDate, end].where((s) => s.trim().isNotEmpty).join(' - ');
  }
}

/// A single education entry.
class EducationItem {
  final String degree;
  final String institution;
  final String fieldOfStudy;
  final String location;
  final String startYear;
  final String endYear;
  final String grade;
  final String description;

  EducationItem({
    this.degree = '',
    this.institution = '',
    this.fieldOfStudy = '',
    this.location = '',
    this.startYear = '',
    this.endYear = '',
    this.grade = '',
    this.description = '',
  });
}

/// A certification with a name, issuing body and optional details.
class CertificationItem {
  final String name;
  final String issuer;
  final String year;
  final String description;

  CertificationItem({this.name = '', this.issuer = '', this.year = '', this.description = ''});
}

class ResumeData {
  final String name;
  final String email;
  final String phone;
  final String linkedin;
  final String github;
  final String summary;
  final List<SkillCategory> skillCategories;
  final List<ExperienceItem> experience;
  final List<String> keyAchievements;
  final List<EducationItem> education;
  final List<CertificationItem> certifications;

  ResumeData({
    required this.name,
    required this.email,
    required this.phone,
    required this.linkedin,
    required this.github,
    required this.summary,
    this.skillCategories = const [],
    this.experience = const [],
    this.keyAchievements = const [],
    this.education = const [],
    this.certifications = const [],
  });

  bool get hasSkills => skillCategories.any((c) => c.skills.isNotEmpty);
}

/// Builds ATS-friendly (plain text-extractable, single-column, no images/tables)
/// resume PDFs in a few different visual styles from the same underlying data.
class ResumePdfGenerator {
  static Future<pw.Document> generate(ResumeData data, ResumeTemplate template, {int primaryColor = 0xFF0F172A, int accentColor = 0xFFEAB308}) async {
    switch (template) {
      case ResumeTemplate.classic:
        return _classic(data, primaryColor: primaryColor, accentColor: accentColor);
      case ResumeTemplate.modern:
        return _modern(data, primaryColor: primaryColor, accentColor: accentColor);
      case ResumeTemplate.minimal:
        return _minimal(data);
    }
  }

  static pw.Widget _sectionTitle(String title, PdfColor color) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
        child: pw.Text(title.toUpperCase(),
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: color, letterSpacing: 1.2)),
      );

  static pw.Widget _divider(PdfColor color) =>
      pw.Container(height: 1, color: color, margin: const pw.EdgeInsets.only(bottom: 4));

  static pw.Widget _bullet(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2, left: 6),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.SizedBox(width: 8, child: pw.Text('-')),
          pw.Expanded(child: pw.Text(text, style: const pw.TextStyle(fontSize: 10))),
        ]),
      );

  static pw.Widget _skillsBlock(ResumeData d) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: d.skillCategories
          .where((c) => c.skills.isNotEmpty)
          .map((c) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 3),
                child: pw.Text('${c.name}: ${c.skills.join(', ')}',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ))
          .toList(),
    );
  }

  static pw.Widget _experienceBlock(List<ExperienceItem> items) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: items.map((e) {
        final title = [e.role, e.company].where((s) => s.trim().isNotEmpty).join(' - ');
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 9),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(title, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            if (e.dateRange.isNotEmpty || e.location.isNotEmpty)
              pw.Text([e.dateRange, e.location].where((s) => s.trim().isNotEmpty).join('  |  '),
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            if (e.description.isNotEmpty)
              pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 2), child: pw.Text(e.description, style: const pw.TextStyle(fontSize: 10))),
            ...e.points.where((p) => p.trim().isNotEmpty).map((p) => _bullet(p)),
          ]),
        );
      }).toList(),
    );
  }

  static pw.Widget _educationBlock(List<EducationItem> items) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: items.map((e) {
        final line1 = [e.degree, e.institution].where((s) => s.trim().isNotEmpty).join(' - ');
        final meta = [e.fieldOfStudy, e.location, _years(e), e.grade].where((s) => s.trim().isNotEmpty).join('  |  ');
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 7),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(line1, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            if (meta.isNotEmpty) pw.Text(meta, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            if (e.description.isNotEmpty) pw.Text(e.description, style: const pw.TextStyle(fontSize: 10)),
          ]),
        );
      }).toList(),
    );
  }

  static String _years(EducationItem e) {
    final list = [e.startYear, e.endYear].where((s) => s.trim().isNotEmpty);
    return list.length == 2 ? '${list.first} - ${list.last}' : (list.isEmpty ? '' : list.first);
  }

  static pw.Widget _certificationsBlock(List<CertificationItem> items) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: items
          .where((c) => c.name.trim().isNotEmpty)
          .map((c) {
            final meta = [c.issuer, c.year].where((s) => s.trim().isNotEmpty).join(' | ');
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(meta.isEmpty ? '-  ${c.name}' : '-  ${c.name}  (${meta})', style: const pw.TextStyle(fontSize: 10)),
                if (c.description.isNotEmpty)
                  pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 12),
                      child: pw.Text(c.description, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700))),
              ]),
            );
          })
          .toList(),
    );
  }

static Future<pw.Document> _classic(ResumeData d, {required int primaryColor, required int accentColor}) async {
    final doc = pw.Document();
    final navy = PdfColor.fromInt(primaryColor);
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(d.name, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: navy)),
        pw.SizedBox(height: 4),
        pw.Text('${d.email}  |  ${d.phone}${d.linkedin.isNotEmpty ? '  |  ${d.linkedin}' : ''}${d.github.isNotEmpty ? '  |  ${d.github}' : ''}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        if (d.summary.isNotEmpty) ...[
          _sectionTitle('Summary', navy),
          _divider(navy),
          pw.Text(d.summary, style: const pw.TextStyle(fontSize: 10)),
        ],
        if (d.hasSkills) ...[
          _sectionTitle('Skills', navy),
          _divider(navy),
          _skillsBlock(d),
        ],
        if (d.experience.isNotEmpty) ...[
          _sectionTitle('Experience', navy),
          _divider(navy),
          _experienceBlock(d.experience),
        ],
        if (d.keyAchievements.isNotEmpty) ...[
          _sectionTitle('Key Achievements', navy),
          _divider(navy),
          ...d.keyAchievements.where((a) => a.trim().isNotEmpty).map((a) => _bullet(a)),
        ],
        if (d.education.isNotEmpty) ...[
          _sectionTitle('Education', navy),
          _divider(navy),
          _educationBlock(d.education),
        ],
        if (d.certifications.isNotEmpty) ...[
          _sectionTitle('Certifications', navy),
          _divider(navy),
          _certificationsBlock(d.certifications),
        ],
      ]),
    ));
    return doc;
  }

  static Future<pw.Document> _modern(ResumeData d, {required int primaryColor, required int accentColor}) async {
    final doc = pw.Document();
    final gold = PdfColor.fromInt(accentColor);
    final navy = PdfColor.fromInt(primaryColor);
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(0),
      build: (context) => pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Container(
          width: 180,
          color: navy,
          padding: const pw.EdgeInsets.all(20),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(d.name, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
            pw.SizedBox(height: 16),
            pw.Text('CONTACT', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: gold)),
            pw.SizedBox(height: 4),
            pw.Text(d.email, style: const pw.TextStyle(fontSize: 9, color: PdfColors.white)),
            pw.Text(d.phone, style: const pw.TextStyle(fontSize: 9, color: PdfColors.white)),
            if (d.linkedin.isNotEmpty) pw.Text(d.linkedin, style: const pw.TextStyle(fontSize: 9, color: PdfColors.white)),
            if (d.github.isNotEmpty) pw.Text(d.github, style: const pw.TextStyle(fontSize: 9, color: PdfColors.white)),
            if (d.hasSkills) ...[
              pw.SizedBox(height: 16),
              pw.Text('SKILLS', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: gold)),
              pw.SizedBox(height: 4),
              ...d.skillCategories.where((c) => c.skills.isNotEmpty).expand((c) => [
                    pw.SizedBox(height: 3),
                    pw.Text(c.name.toUpperCase(), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: gold)),
                    ...c.skills.map((s) => pw.Text('- $s', style: const pw.TextStyle(fontSize: 9, color: PdfColors.white))),
                  ]),
            ],
            if (d.certifications.isNotEmpty) ...[
              pw.SizedBox(height: 16),
              pw.Text('CERTIFICATIONS', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: gold)),
              pw.SizedBox(height: 4),
              ...d.certifications.where((c) => c.name.trim().isNotEmpty).map((c) {
                final meta = [c.issuer, c.year].where((s) => s.trim().isNotEmpty).join(' | ');
                return pw.Text(meta.isEmpty ? '- ${c.name}' : '- ${c.name} (${meta})',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.white));
              }),
            ],
          ]),
        ),
        pw.Expanded(
          child: pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              if (d.summary.isNotEmpty) ...[
                _sectionTitle('Profile', navy),
                _divider(gold),
                pw.Text(d.summary, style: const pw.TextStyle(fontSize: 10)),
              ],
              if (d.experience.isNotEmpty) ...[
                _sectionTitle('Experience', navy),
                _divider(gold),
                _experienceBlock(d.experience),
              ],
              if (d.keyAchievements.isNotEmpty) ...[
                _sectionTitle('Key Achievements', navy),
                _divider(gold),
                ...d.keyAchievements.where((a) => a.trim().isNotEmpty).map((a) => _bullet(a)),
              ],
              if (d.education.isNotEmpty) ...[
                _sectionTitle('Education', navy),
                _divider(gold),
                _educationBlock(d.education),
              ],
            ]),
          ),
        ),
      ]),
    ));
    return doc;
  }

static Future<pw.Document> _minimal(ResumeData d) async {
    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (context) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(d.name, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.normal)),
        pw.Text('${d.email} | ${d.phone}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.SizedBox(height: 16),
        if (d.summary.isNotEmpty) pw.Text(d.summary, style: const pw.TextStyle(fontSize: 10)),
        if (d.hasSkills) ...[
          pw.SizedBox(height: 12),
          pw.Text('Skills', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          _skillsBlock(d),
        ],
        if (d.experience.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          pw.Text('Experience', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          _experienceBlock(d.experience),
        ],
        if (d.keyAchievements.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          pw.Text('Key Achievements', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          ...d.keyAchievements.where((a) => a.trim().isNotEmpty).map((a) => _bullet(a)),
        ],
        if (d.education.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          pw.Text('Education', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          _educationBlock(d.education),
        ],
        if (d.certifications.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          pw.Text('Certifications', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          _certificationsBlock(d.certifications),
        ],
      ]),
    ));
    return doc;
  }
}
