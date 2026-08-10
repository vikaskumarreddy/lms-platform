import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/common_header.dart';
import '../../../data/models/lesson.dart';
import '../../../core/services/api_service.dart';

class CourseSectionLessonsScreen extends StatefulWidget {
  final int sectionId;
  const CourseSectionLessonsScreen({super.key, required this.sectionId});

  @override
  State<CourseSectionLessonsScreen> createState() => _CourseSectionLessonsScreenState();
}

class _CourseSectionLessonsScreenState extends State<CourseSectionLessonsScreen> {
  List<Lesson> _lessons = [];
  String _sectionTitle = 'Lessons';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLessons();
  }

  Future<void> _loadLessons() async {
    final api = ApiService();
    // The sectionId here is actually the moduleId from the backend
    final lessons = await api.getModuleLessons(widget.sectionId);
    setState(() {
      _lessons = lessons;
      _sectionTitle = '${lessons.length} Lessons';
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonHeader(showBackButton: true, title: _sectionTitle),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('${_lessons.length} lessons available', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                const SizedBox(height: 16),
                if (_lessons.isEmpty)
                  Center(child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text('No lessons available', style: TextStyle(color: Colors.grey.shade500)),
                  ))
                else
                  ..._lessons.map((lesson) => _LessonTile(lesson: lesson)),
                const SizedBox(height: 20),
              ],
            ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  final Lesson lesson;

  const _LessonTile({required this.lesson});

  @override
  Widget build(BuildContext context) {
    final secondaryColor = const Color(0xFFEAB308);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: lesson.isLocked
            ? () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Upgrade your subscription to unlock this lesson')),
                );
              }
            : () => context.go('/lesson/${lesson.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: lesson.completed ? Colors.green.withOpacity(0.1) : secondaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: lesson.isLocked
                    ? Icon(Icons.lock, color: Colors.grey, size: 22)
                    : Icon(lesson.completed ? Icons.check_circle : Icons.play_circle_outline, color: lesson.completed ? Colors.green : secondaryColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lesson.title, style: TextStyle(fontSize: 14, fontWeight: lesson.completed ? FontWeight.w500 : FontWeight.normal, color: lesson.isLocked ? Colors.grey : Colors.grey.shade800)),
                    const SizedBox(height: 2),
                    Text(lesson.duration, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              Icon(lesson.isLocked ? Icons.lock_outline : Icons.chevron_right, color: lesson.isLocked ? Colors.grey : secondaryColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
