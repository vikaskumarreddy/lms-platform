import 'package:flutter/material.dart';
import '../../../core/widgets/common_header.dart';
import '../../../core/services/api_service.dart';
import '../../../data/models/question_model.dart';

class QaScreen extends StatefulWidget {
  const QaScreen({super.key});
  @override
  State<QaScreen> createState() => _QaScreenState();
}

class _QaScreenState extends State<QaScreen> {
  String _selectedFilter = 'All';
  final _questionController = TextEditingController();
  final _titleController = TextEditingController();
  final _categoryController = TextEditingController();
  bool _showAskForm = false;
  bool _isLoading = true;
  List<QuestionModel> _questions = [];

  final List<String> _filters = ['All', 'Java', 'SQL', 'DSA', 'Web', 'Coding'];

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      final questions = await ApiService().getQuestions();
      if (!mounted) return;
      setState(() {
        _questions = questions;
        final backendCategories = questions.map((q) => q.category).toSet().toList();
        for (final cat in backendCategories) {
          if (cat.isNotEmpty && !_filters.contains(cat)) {
            _filters.add(cat);
          }
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<QuestionModel> get _filteredQuestions {
    if (_selectedFilter == 'All') return _questions;
    return _questions.where((q) => q.category == _selectedFilter).toList();
  }

  @override
  void dispose() {
    _questionController.dispose();
    _titleController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  String _formatTimeAgo(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return 'Recently';
    final date = DateTime.tryParse(isoDate);
    if (date == null) return 'Recently';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 2) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.year}/${date.month}/${date.day}';
  }

  Color _categoryColor(String category) {
    final colors = <Color>[
      const Color(0xFF3B82F6), const Color(0xFF10B981), const Color(0xFF8B5CF6),
      const Color(0xFF06B6D4), const Color(0xFFF97316), const Color(0xFFEC4899),
    ];
    return colors[category.hashCode % colors.length];
  }

  String _authorInitial(String authorName) {
    if (authorName.isEmpty) return '?';
    return authorName[0].toUpperCase();
  }

  void _submitQuestion() async {
    final text = _questionController.text.trim();
    final title = _titleController.text.trim();
    final category = _categoryController.text.trim().isEmpty ? 'General' : _categoryController.text.trim();
    if (text.isEmpty || title.isEmpty) return;

    final result = await ApiService().createQuestion(
      title: title,
      content: text,
      category: category,
    );

    if (result != null) {
      if (!mounted) return;
      setState(() {
        _showAskForm = false;
        _questionController.clear();
        _titleController.clear();
        _categoryController.clear();
        _questions.insert(0, result);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your question has been posted successfully'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to post question. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF0F172A);
    final secondaryColor = const Color(0xFFEAB308);

    return Scaffold(
      appBar: const CommonHeader(title: 'Q&A'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => setState(() => _showAskForm = !_showAskForm),
        backgroundColor: secondaryColor,
        foregroundColor: primaryColor,
        icon: Icon(_showAskForm ? Icons.close : Icons.add),
        label: Text(_showAskForm ? 'Cancel' : 'Ask Question'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_showAskForm)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: secondaryColor.withOpacity(0.5)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Ask a Question', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: primaryColor)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          hintText: 'Question title',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Color(0xFFF8FAFC),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _questionController,
                        maxLines: 3,
                        maxLength: 500,
                        decoration: const InputDecoration(
                          hintText: 'Describe your question in detail...',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Color(0xFFF8FAFC),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: ['Java', 'SQL', 'DSA', 'Web', 'Coding'].map((tag) =>
                              FilterChip(
                                label: Text(tag, style: const TextStyle(fontSize: 11)),
                                selected: _categoryController.text == tag,
                                onSelected: (_) => setState(() => _categoryController.text = tag),
                                visualDensity: VisualDensity.compact,
                              ),
                            ).toList(),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _submitQuestion,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: secondaryColor,
                            foregroundColor: primaryColor,
                          ),
                          child: const Text('Post Question'),
                        ),
                      ]),
                    ]),
                  ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, primaryColor.withOpacity(0.85)],
                    ),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Community Q&A', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      '${_questions.length} questions • ${_questions.where((q) => q.isAnswered).length} answered',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                  ]),
                ),
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    children: _filters.map((filter) {
                      final isSelected = _selectedFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(filter),
                          selected: isSelected,
                          onSelected: (_) => setState(() => _selectedFilter = filter),
                          selectedColor: secondaryColor,
                          labelStyle: TextStyle(
                            color: isSelected ? primaryColor : Colors.grey.shade700,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Expanded(
                  child: _filteredQuestions.isEmpty
                      ? Center(
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.forum_outlined, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text('No questions yet', style: TextStyle(color: Colors.grey.shade500)),
                            const SizedBox(height: 4),
                            Text('Be the first to ask!', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                          ]),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadQuestions,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                            itemCount: _filteredQuestions.length,
                            itemBuilder: (context, index) => _QuestionCard(
                              qa: _filteredQuestions[index],
                              formatTimeAgo: _formatTimeAgo,
                              categoryColor: _categoryColor,
                              authorInitial: _authorInitial,
                            ),
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final QuestionModel qa;
  final String Function(String?) formatTimeAgo;
  final Color Function(String) categoryColor;
  final String Function(String) authorInitial;

  const _QuestionCard({
    required this.qa,
    required this.formatTimeAgo,
    required this.categoryColor,
    required this.authorInitial,
  });

  @override
  Widget build(BuildContext context) {
    final secondaryColor = const Color(0xFFEAB308);
    final authorColor = categoryColor(qa.category);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: authorColor.withOpacity(0.15),
              child: Text(authorInitial(qa.authorName), style: TextStyle(color: authorColor, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(qa.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text('${qa.authorName} • ${formatTimeAgo(qa.createdAt)}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: authorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(qa.category, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: authorColor)),
                ),
              ]),
            ),
            IconButton(
              icon: Icon(
                qa.answerCount > 0 ? Icons.chat_bubble : Icons.chat_bubble_outline,
                color: qa.answerCount > 0 ? Colors.green : Colors.grey.shade400,
                size: 18,
              ),
              onPressed: () {},
              tooltip: '${qa.answerCount} answers',
            ),
          ]),
          const SizedBox(height: 8),
          if (qa.content.isNotEmpty)
            Text(
              qa.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
            ),
          const SizedBox(height: 10),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: qa.isAnswered ? Colors.green.withOpacity(0.1) : secondaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Icon(
                  qa.isAnswered ? Icons.check_circle : Icons.hourglass_empty,
                  size: 12,
                  color: qa.isAnswered ? Colors.green : const Color(0xFFB45309),
                ),
                const SizedBox(width: 4),
                Text(
                  '${qa.answerCount} Answers',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: qa.isAnswered ? Colors.green : const Color(0xFFB45309),
                  ),
                ),
              ]),
            ),
            const SizedBox(width: 12),
            Icon(Icons.thumb_up_outlined, size: 14, color: Colors.grey.shade500),
            const SizedBox(width: 4),
            Text('${qa.voteCount}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const Spacer(),
            Text('View', style: TextStyle(fontSize: 12, color: Colors.blue.shade600, fontWeight: FontWeight.w600)),
          ]),
        ]),
      ),
    );
  }
}
