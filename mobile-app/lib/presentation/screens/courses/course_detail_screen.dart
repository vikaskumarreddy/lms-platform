import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/common_header.dart';
import '../../../data/models/course_section.dart';
import '../../../core/services/api_service.dart';

class CourseDetailScreen extends StatefulWidget {
  final int id;
  const CourseDetailScreen({super.key, required this.id});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  List<CourseSection> _sections = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSections();
  }

  Future<void> _loadSections() async {
    final api = ApiService();
    final sections = await api.getCourseSections(widget.id);
    setState(() {
      _sections = sections;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonHeader(title: 'Course Sections'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Select a section to view lessons', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                const SizedBox(height: 16),
                if (_sections.isEmpty)
                  Center(child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text('No sections available', style: TextStyle(color: Colors.grey.shade500)),
                  ))
                else
                  ..._sections.map((section) => _SectionCard(section: section, courseId: widget.id)),
                const SizedBox(height: 20),
              ],
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final CourseSection section;
  final int courseId;

  const _SectionCard({required this.section, required this.courseId});

  @override
  Widget build(BuildContext context) {
    final sectionColor = _parseColor(section.color);
    final progress = section.totalLessons > 0 ? section.completedLessons / section.totalLessons : 0.0;
    final secondaryColor = const Color(0xFFEAB308);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: section.isLocked
            ? () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Upgrade your subscription to unlock this section')),
                );
              }
            : () => context.go('/courses/$courseId/sections/${section.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: sectionColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: section.isLocked
                      ? Icon(Icons.lock, color: sectionColor, size: 28)
                      : Text(section.icon, style: const TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(section.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(section.description, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: section.isLocked ? 0.0 : progress,
                        minHeight: 4,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation(section.isLocked ? Colors.grey : sectionColor),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      section.isLocked ? 'Locked' : '${section.completedLessons}/${section.totalLessons} lessons • ${(progress * 100).toInt()}%',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              Icon(section.isLocked ? Icons.lock_outline : Icons.chevron_right, color: section.isLocked ? Colors.grey : secondaryColor),
            ],
          ),
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    if (hex.isEmpty) return const Color(0xFFEAB308);
    var value = hex.replaceFirst('#', '');
    if (value.length == 6) value = 'FF$value';
    final parsed = int.tryParse(value, radix: 16);
    return parsed != null ? Color(parsed) : const Color(0xFFEAB308);
  }
}
