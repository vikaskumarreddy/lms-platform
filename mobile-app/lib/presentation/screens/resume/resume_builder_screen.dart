import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/utils/resume_pdf_generator.dart';
import '../../../core/widgets/common_header.dart';

class ResumeBuilderScreen extends ConsumerStatefulWidget {
  const ResumeBuilderScreen({super.key});
  @override
  ConsumerState<ResumeBuilderScreen> createState() => _ResumeBuilderScreenState();
}

class _ResumeBuilderScreenState extends ConsumerState<ResumeBuilderScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _githubController = TextEditingController();
  final _summaryController = TextEditingController();

  // ---- Skills are collected category-wise (e.g. Programming Languages: Java, Python).
  static const defaultCategories = <String>['Programming Languages', 'AI', 'Tools', 'Technologies'];
  late final Map<String, List<String>> _skillsByCategory = {
    for (final c in defaultCategories) c: <String>[],
  };
  String _activeSkillCategory = defaultCategories.first;
  final _newSkillController = TextEditingController();
  final _achievementController = TextEditingController();

  // ---- Experience, Key Achievements, Education, Certifications.
  final List<ExperienceItem> _experience = [];
  final List<String> _keyAchievements = [];
  final List<EducationItem> _education = [];
  final List<CertificationItem> _certifications = [];

  ResumeTemplate _template = ResumeTemplate.modern;
  bool _prefilled = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _linkedinController.dispose();
    _githubController.dispose();
    _summaryController.dispose();
    _newSkillController.dispose();
    _achievementController.dispose();
    super.dispose();
  }

  void _prefillFromProfile(Map<String, dynamic>? profile) {
    if (_prefilled || profile == null) return;
    _prefilled = true;
    _nameController.text = profile['name'] ?? '';
    _emailController.text = profile['email'] ?? '';
    _phoneController.text = profile['phone'] ?? '';
    _linkedinController.text = profile['linkedin'] ?? '';
    _githubController.text = profile['github'] ?? '';
  }

  List<SkillCategory> get _skillCategories =>
      _skillsByCategory.entries.map((e) => SkillCategory(e.key, List.of(e.value))).toList();

  ResumeData get _data => ResumeData(
        name: _nameController.text.trim().isEmpty ? 'Your Name' : _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        linkedin: _linkedinController.text.trim(),
        github: _githubController.text.trim(),
        summary: _summaryController.text.trim(),
        skillCategories: _skillCategories,
        experience: List.of(_experience),
        keyAchievements: List.of(_keyAchievements),
        education: List.of(_education),
        certifications: List.of(_certifications),
      );

  Future<void> _preview() async {
    final org = ref.read(orgThemeProvider);
    final doc = await ResumePdfGenerator.generate(_data, _template, primaryColor: org.primary.value, accentColor: org.accent.value);
    final bytes = await doc.save();
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => _ResumePreviewScreen(pdfBytes: bytes)));
  }

  Future<void> _download() async {
    final org = ref.read(orgThemeProvider);
    final doc = await ResumePdfGenerator.generate(_data, _template, primaryColor: org.primary.value, accentColor: org.accent.value);
    final bytes = await doc.save();
    await Printing.sharePdf(bytes: bytes, filename: 'Resume_${_nameController.text.trim().replaceAll(' ', '_')}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    _prefillFromProfile(profileAsync.asData?.value);

    final org = ref.watch(orgThemeProvider);

    return Scaffold(
      appBar: CommonHeader(
        title: 'Resume Builder',
        actions: [
          IconButton(icon: const Icon(Icons.visibility_outlined), tooltip: 'Preview', onPressed: _preview),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _templateSelector(org.accent, org.primary),
          const SizedBox(height: 16),
          _personalInfoCard(org.primary),
          const SizedBox(height: 16),
          _summaryCard(org.primary),
          const SizedBox(height: 16),
          _skillsCard(org.primary, org.accent),
          const SizedBox(height: 16),
          _experienceCard(org.primary, org.accent),
          const SizedBox(height: 16),
          _achievementsCard(org.primary, org.accent),
          const SizedBox(height: 16),
          _educationCard(org.primary, org.accent),
          const SizedBox(height: 16),
          _certificationsCard(org.primary, org.accent),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _download,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Generate ATS-Friendly Resume PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: org.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _templateSelector(Color accent, Color primary) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Template', style: TextStyle(fontWeight: FontWeight.bold, color: primary, fontSize: 15)),
          const SizedBox(height: 12),
          Row(
            children: ResumeTemplate.values.map((t) {
              final isSelected = _template == t;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _template = t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? accent.withOpacity(0.15) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isSelected ? accent : Colors.grey.shade300),
                      ),
                      child: Column(children: [
                        Icon(Icons.description_outlined, color: isSelected ? accent : Colors.grey.shade600),
                        const SizedBox(height: 4),
                        Text(t.name[0].toUpperCase() + t.name.substring(1),
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? accent : Colors.grey.shade700)),
                      ]),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ]),
      ),
    );
  }

Widget _personalInfoCard(Color primary) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.person, color: primary),
            const SizedBox(width: 12),
            Text('Personal Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: primary)),
          ]),
          const SizedBox(height: 16),
          TextField(controller: _nameController, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Full Name *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_outline))),
          const SizedBox(height: 12),
          TextField(controller: _emailController, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Email *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email_outlined))),
          const SizedBox(height: 12),
          TextField(controller: _phoneController, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone_outlined))),
          const SizedBox(height: 12),
          TextField(controller: _linkedinController, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'LinkedIn', border: OutlineInputBorder(), prefixIcon: Icon(Icons.link))),
          const SizedBox(height: 12),
          TextField(controller: _githubController, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'GitHub', border: OutlineInputBorder(), prefixIcon: Icon(Icons.code))),
        ]),
      ),
    );
  }

  Widget _summaryCard(Color primary) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.notes, color: primary),
            const SizedBox(width: 12),
            Text('Professional Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: primary)),
          ]),
          const SizedBox(height: 16),
          TextField(
            controller: _summaryController,
            onChanged: (_) => setState(() {}),
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Summary', border: OutlineInputBorder(), alignLabelWithHint: true, hintText: 'A brief 2-3 line summary of your profile...'),
          ),
        ]),
      ),
    );
  }

  Widget _skillsCard(Color primary, Color accent) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.star_outline, color: primary),
            const SizedBox(width: 12),
            Text('Skills', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: primary)),
          ]),
          const SizedBox(height: 4),
          Text('Choose a category first, then add skills under it.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _activeSkillCategory,
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder(), prefixIcon: Icon(Icons.category_outlined)),
                items: _skillsByCategory.keys.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _activeSkillCategory = v ?? _activeSkillCategory),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _addCustomCategory,
              icon: const Icon(Icons.add),
              tooltip: 'Add category',
              style: IconButton.styleFrom(backgroundColor: accent),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _newSkillController,
                decoration: InputDecoration(labelText: 'Add a skill to $_activeSkillCategory', border: const OutlineInputBorder()),
                onSubmitted: (_) => _addSkill(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(onPressed: _addSkill, icon: const Icon(Icons.add), style: IconButton.styleFrom(backgroundColor: accent)),
          ]),
          const SizedBox(height: 16),
          ..._skillsByCategory.entries.map((entry) {
            final skills = entry.value;
            if (skills.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(entry.key, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: skills.map((s) => Chip(
                        label: Text(s),
                        onDeleted: () => setState(() => _skillsByCategory[entry.key]?.remove(s)),
                      )).toList(),
                ),
              ]),
            );
          }).toList(),
        ]),
      ),
    );
  }

  void _addSkill() {
    final value = _newSkillController.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _skillsByCategory[_activeSkillCategory]?.add(value);
      _newSkillController.clear();
    });
  }

  Future<void> _addCustomCategory() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New skill category'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Category name', border: OutlineInputBorder()), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Add')),
        ],
      ),
    );
    if (name == null || name.isEmpty || _skillsByCategory.containsKey(name)) return;
    setState(() {
      _skillsByCategory[name] = [];
      _activeSkillCategory = name;
    });
  }

  Widget _experienceCard(Color primary, Color accent) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Icon(Icons.work_outline, color: primary),
              const SizedBox(width: 12),
              Text('Experience', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: primary)),
            ]),
            TextButton.icon(
              onPressed: () => _editExperience(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
            ),
          ]),
          const SizedBox(height: 4),
          Text('Add each role in detail with achievement bullet points.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 12),
          if (_experience.isEmpty)
            Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('No experience added yet', style: TextStyle(color: Colors.grey))))
          else
            ..._experience.asMap().entries.map((entry) {
              final index = entry.key;
              final e = entry.value;
              return Card(
                color: Colors.grey.shade50,
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text([e.role, e.company].where((s) => s.trim().isNotEmpty).join(' - '), style: const TextStyle(fontWeight: FontWeight.bold)),
                          if (e.dateRange.isNotEmpty || e.location.isNotEmpty)
                            Text([e.dateRange, e.location].where((s) => s.trim().isNotEmpty).join('  |  '), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ]),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () => _editExperience(existing: e, index: index),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 20),
                        onPressed: () => setState(() => _experience.removeAt(index)),
                      ),
                    ]),
                    if (e.description.isNotEmpty)
                      Padding(padding: const EdgeInsets.only(top: 4), child: Text(e.description, style: const TextStyle(fontSize: 13))),
                    ...e.points.where((p) => p.trim().isNotEmpty).map((p) => Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Padding(padding: EdgeInsets.only(right: 6), child: Text('•', style: TextStyle(fontSize: 13))),
                            Expanded(child: Text(p, style: const TextStyle(fontSize: 13))),
                          ]),
                        )),
                  ]),
                ),
              );
            }),
        ]),
      ),
    );
  }

Future<void> _editExperience({ExperienceItem? existing, int? index}) async {
    final role = TextEditingController(text: existing?.role ?? '');
    final company = TextEditingController(text: existing?.company ?? '');
    final location = TextEditingController(text: existing?.location ?? '');
    final startDate = TextEditingController(text: existing?.startDate ?? '');
    final endDate = TextEditingController(text: existing?.endDate ?? '');
    final description = TextEditingController(text: existing?.description ?? '');
    bool current = existing?.current ?? false;
    final points = (existing?.points ?? const <String>[]).map((p) => TextEditingController(text: p)).toList();

    await showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (sheetCtx) {
        return StatefulBuilder(builder: (sheetCtx, setSheet) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(existing == null ? 'Add Experience' : 'Edit Experience',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(controller: role, decoration: const InputDecoration(labelText: 'Job Title / Role *', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: company, decoration: const InputDecoration(labelText: 'Company / Organization *', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: location, decoration: const InputDecoration(labelText: 'Location', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: startDate, decoration: const InputDecoration(labelText: 'Start (e.g. Jun 2021)', border: OutlineInputBorder()))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: endDate, decoration: const InputDecoration(labelText: 'End (e.g. Aug 2023)', border: OutlineInputBorder()))),
                ]),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Currently working here'),
                  value: current,
                  onChanged: (v) => setSheet(() => current = v),
                ),
                const SizedBox(height: 4),
                TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder(), alignLabelWithHint: true)),
                const SizedBox(height: 16),
                Text('Achievements / Points', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...points.asMap().entries.map((entry) {
                  final i = entry.key;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Expanded(child: TextField(controller: entry.value, decoration: InputDecoration(border: const OutlineInputBorder(), hintText: 'Point ${i + 1}'))),
                      IconButton(
                        icon: Icon(Icons.remove_circle_outline, color: Colors.red.shade400),
                        onPressed: () => setSheet(() => points.removeAt(i)),
                      ),
                    ]),
                  );
                }),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setSheet(() => points.add(TextEditingController())),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add point'),
                  ),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(sheetCtx), child: const Text('Cancel'))),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(sheetCtx, true), child: const Text('Save'))),
                ]),
              ]),
            ),
          );
        });
      },
    );

    // Collect the result and update state; ignore empty entries.
    final item = ExperienceItem(
      role: role.text.trim(),
      company: company.text.trim(),
      location: location.text.trim(),
      startDate: startDate.text.trim(),
      endDate: current ? '' : endDate.text.trim(),
      current: current,
      description: description.text.trim(),
      points: points.map((p) => p.text.trim()).where((p) => p.isNotEmpty).toList(),
    );
    if (item.role.isEmpty && item.company.isEmpty && item.description.isEmpty && item.points.isEmpty) return;
    if (mounted) {
      setState(() {
        if (index != null && index < _experience.length) {
          _experience[index] = item;
        } else {
          _experience.add(item);
        }
      });
    }
  }

Widget _achievementsCard(Color primary, Color accent) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.emoji_events_outlined, color: primary),
            const SizedBox(width: 12),
            Text('Key Achievements', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: primary)),
          ]),
          const SizedBox(height: 4),
          Text('Awards, top ranks, notable wins, recognition.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 12),
          if (_keyAchievements.isEmpty)
            Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('No achievements added yet', style: TextStyle(color: Colors.grey))))
          else
            ..._keyAchievements.asMap().entries.map((entry) {
              final i = entry.key;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(Icons.star, color: Theme.of(context).colorScheme.secondary),
                title: Text(entry.value),
                trailing: IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                  onPressed: () => setState(() => _keyAchievements.removeAt(i)),
                ),
              );
            }),
          TextField(
            controller: _achievementController,
            decoration: const InputDecoration(labelText: 'Add an achievement', border: OutlineInputBorder(), suffixIcon: Icon(Icons.add_circle_outline)),
            onSubmitted: (_) => _addAchievement(),
          ),
        ]),
      ),
    );
  }

  void _addAchievement() {
    final value = _achievementController.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _keyAchievements.add(value);
      _achievementController.clear();
    });
  }

Widget _educationCard(Color primary, Color accent) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Icon(Icons.school_outlined, color: primary),
              const SizedBox(width: 12),
              Text('Education', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: primary)),
            ]),
            TextButton.icon(
              onPressed: () => _editEducation(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
            ),
          ]),
          const SizedBox(height: 4),
          Text('Degrees and courses with scores and details.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 12),
          if (_education.isEmpty)
            Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('No education added yet', style: TextStyle(color: Colors.grey))))
          else
            ..._education.asMap().entries.map((entry) {
              final index = entry.key;
              final e = entry.value;
              final line1 = [e.degree, e.institution].where((s) => s.trim().isNotEmpty).join(' - ');
              final meta = [e.fieldOfStudy, e.location, _eduYears(e), e.grade].where((s) => s.trim().isNotEmpty).join('  |  ');
              return Card(
                color: Colors.grey.shade50,
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  contentPadding: const EdgeInsets.only(left: 12, right: 4),
                  leading: const CircleAvatar(child: Icon(Icons.school, color: Colors.blueGrey)),
                  title: Text(line1, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (meta.isNotEmpty) Text(meta, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    if (e.description.isNotEmpty) Text(e.description, style: const TextStyle(fontSize: 12)),
                  ]),
                  isThreeLine: e.description.isNotEmpty,
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => _editEducation(existing: e, index: index),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 20),
                      onPressed: () => setState(() => _education.removeAt(index)),
                    ),
                  ]),
                ),
              );
            }),
        ]),
      ),
    );
  }

  String _eduYears(EducationItem e) {
    final list = [e.startYear, e.endYear].where((s) => s.trim().isNotEmpty);
    return list.length == 2 ? '${list.first} - ${list.last}' : (list.isEmpty ? '' : list.first);
  }

Future<void> _editEducation({EducationItem? existing, int? index}) async {
    final degree = TextEditingController(text: existing?.degree ?? '');
    final institution = TextEditingController(text: existing?.institution ?? '');
    final fieldOfStudy = TextEditingController(text: existing?.fieldOfStudy ?? '');
    final location = TextEditingController(text: existing?.location ?? '');
    final startYear = TextEditingController(text: existing?.startYear ?? '');
    final endYear = TextEditingController(text: existing?.endYear ?? '');
    final grade = TextEditingController(text: existing?.grade ?? '');
    final description = TextEditingController(text: existing?.description ?? '');

    await showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(existing == null ? 'Add Education' : 'Edit Education',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(controller: degree, decoration: const InputDecoration(labelText: 'Degree / Qualification *', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: institution, decoration: const InputDecoration(labelText: 'Institution / University *', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: fieldOfStudy, decoration: const InputDecoration(labelText: 'Field of Study / Major', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: location, decoration: const InputDecoration(labelText: 'Location', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: startYear, decoration: const InputDecoration(labelText: 'Start Year', border: OutlineInputBorder()))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: endYear, decoration: const InputDecoration(labelText: 'End Year', border: OutlineInputBorder()))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: grade, decoration: const InputDecoration(labelText: 'Grade / CGPA', border: OutlineInputBorder()))),
              ]),
              const SizedBox(height: 12),
              TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description / Activities', border: OutlineInputBorder(), alignLabelWithHint: true)),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(sheetCtx), child: const Text('Cancel'))),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(sheetCtx, true), child: const Text('Save'))),
              ]),
            ]),
          ),
        );
      },
    );

    final item = EducationItem(
      degree: degree.text.trim(),
      institution: institution.text.trim(),
      fieldOfStudy: fieldOfStudy.text.trim(),
      location: location.text.trim(),
      startYear: startYear.text.trim(),
      endYear: endYear.text.trim(),
      grade: grade.text.trim(),
      description: description.text.trim(),
    );
    if (item.degree.isEmpty && item.institution.isEmpty && item.description.isEmpty) return;
    if (mounted) {
      setState(() {
        if (index != null && index < _education.length) {
          _education[index] = item;
        } else {
          _education.add(item);
        }
      });
    }
  }

Widget _certificationsCard(Color primary, Color accent) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Icon(Icons.verified_outlined, color: primary),
              const SizedBox(width: 12),
              Text('Certifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: primary)),
            ]),
            TextButton.icon(
              onPressed: () => _editCertification(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
            ),
          ]),
          const SizedBox(height: 4),
          Text('Name them clearly and add the issuing body and details.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 12),
          if (_certifications.isEmpty)
            Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('No certifications added yet', style: TextStyle(color: Colors.grey))))
          else
            ..._certifications.asMap().entries.map((entry) {
              final index = entry.key;
              final c = entry.value;
              final meta = [c.issuer, c.year].where((s) => s.trim().isNotEmpty).join('  |  ');
              return Card(
                color: Colors.grey.shade50,
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  contentPadding: const EdgeInsets.only(left: 12, right: 4),
                  leading: const CircleAvatar(child: Icon(Icons.verified, color: Colors.green)),
                  title: Text(c.name.isEmpty ? 'Certificate' : c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (meta.isNotEmpty) Text(meta, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    if (c.description.isNotEmpty) Text(c.description, style: const TextStyle(fontSize: 12)),
                  ]),
                  isThreeLine: c.description.isNotEmpty,
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => _editCertification(existing: c, index: index),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 20),
                      onPressed: () => setState(() => _certifications.removeAt(index)),
                    ),
                  ]),
                ),
              );
            }),
        ]),
      ),
    );
  }

Future<void> _editCertification({CertificationItem? existing, int? index}) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final issuer = TextEditingController(text: existing?.issuer ?? '');
    final year = TextEditingController(text: existing?.year ?? '');
    final description = TextEditingController(text: existing?.description ?? '');

    await showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(existing == null ? 'Add Certification' : 'Edit Certification',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(controller: name,
                  decoration: const InputDecoration(labelText: 'Certification Name *', border: OutlineInputBorder(), hintText: 'e.g. AWS Certified Solutions Architect')),
              const SizedBox(height: 12),
              TextField(controller: issuer, decoration: const InputDecoration(labelText: 'Issuer / Organization', border: OutlineInputBorder(), hintText: 'e.g. Amazon Web Services')),
              const SizedBox(height: 12),
              TextField(controller: year, decoration: const InputDecoration(labelText: 'Year', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: description,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder(), alignLabelWithHint: true, hintText: 'What you learned / why it matters...')),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(sheetCtx), child: const Text('Cancel'))),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(sheetCtx, true), child: const Text('Save'))),
              ]),
            ]),
          ),
        );
      },
    );

    final item = CertificationItem(
      name: name.text.trim(),
      issuer: issuer.text.trim(),
      year: year.text.trim(),
      description: description.text.trim(),
    );
    if (item.name.isEmpty && item.description.isEmpty) return;
    if (mounted) {
      setState(() {
        if (index != null && index < _certifications.length) {
          _certifications[index] = item;
        } else {
          _certifications.add(item);
        }
      });
    }
  }
}

class _ResumePreviewScreen extends StatelessWidget {
  final Uint8List pdfBytes;
  const _ResumePreviewScreen({required this.pdfBytes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonHeader(showBackButton: true, title: 'Resume Preview'),
      body: PdfPreview(
        build: (format) async => pdfBytes,
        allowSharing: true,
        allowPrinting: true,
        canChangePageFormat: false,
      ),
    );
  }
}


