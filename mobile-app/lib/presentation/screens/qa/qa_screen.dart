import 'package:flutter/material.dart';
import '../../../core/widgets/common_header.dart';

class QaScreen extends StatefulWidget {
  const QaScreen({super.key});
  @override
  State<QaScreen> createState() => _QaScreenState();
}

class _QaScreenState extends State<QaScreen> {
  String _selectedFilter = 'All';
  final _questionController = TextEditingController();
  bool _showAskForm = false;

  final List<String> _filters = ['All', 'Java', 'SQL', 'DSA', 'Web', 'Coding'];

  final List<_QAItem> _questions = [
    _QAItem(
      id: 1,
      title: 'What is the difference between == and .equals() in Java?',
      question: 'I am confused about when to use == and when to use .equals() for string comparison in Java.',
      author: 'Rahul Kumar',
      time: '2 hours ago',
      category: 'Java',
      answers: 4,
      votes: 12,
      isAnswered: true,
      authorInitial: 'R',
      authorColor: const Color(0xFF3B82F6),
      answersList: [
        _Answer(author: 'Priya Sharma', time: '1 hour ago', body: '== compares object references, .equals() compares content. For strings always use .equals().', votes: 8, isAccepted: true),
      ],
    ),
    _QAItem(
      id: 2,
      title: 'How to optimize SQL queries with large datasets?',
      question: 'I have a query that runs slowly on a table with millions of rows.',
      author: 'Sneha Reddy',
      time: '5 hours ago',
      category: 'SQL',
      answers: 3,
      votes: 9,
      isAnswered: true,
      authorInitial: 'S',
      authorColor: const Color(0xFF10B981),
      answersList: [
        _Answer(author: 'Vikram Singh', time: '3 hours ago', body: 'Add indexes on WHERE columns, avoid SELECT *, use EXPLAIN ANALYZE.', votes: 6, isAccepted: true),
      ],
    ),
    _QAItem(
      id: 3,
      title: 'How to reverse a linked list recursively?',
      question: 'I understand iterative approach but struggling with recursive solution.',
      author: 'Arjun Nair',
      time: '1 day ago',
      category: 'DSA',
      answers: 2,
      votes: 15,
      isAnswered: true,
      authorInitial: 'A',
      authorColor: const Color(0xFF8B5CF6),
      answersList: [
        _Answer(author: 'Kavya Iyer', time: '20 hours ago', body: 'Assume rest is reversed, then fix pointers. Base case: null or single node.', votes: 10, isAccepted: true),
      ],
    ),
    _QAItem(
      id: 4,
      title: 'What is hoisting in JavaScript?',
      question: 'I need a clear explanation with examples about var vs let vs const hoisting.',
      author: 'Rohan Das',
      time: '2 days ago',
      category: 'Web',
      answers: 0,
      votes: 5,
      isAnswered: false,
      authorInitial: 'R',
      authorColor: const Color(0xFF06B6D4),
      answersList: [],
    ),
    _QAItem(
      id: 5,
      title: 'How to handle null pointer exceptions in Java?',
      question: 'What are the best practices for avoiding NullPointerExceptions?',
      author: 'Pooja Verma',
      time: '3 days ago',
      category: 'Java',
      answers: 5,
      votes: 18,
      isAnswered: true,
      authorInitial: 'P',
      authorColor: const Color(0xFFF97316),
      answersList: [
        _Answer(author: 'Arun Kumar', time: '2 days ago', body: 'Use Objects.requireNonNull(), Optional for return types, never return null.', votes: 12, isAccepted: true),
      ],
    ),
  ];

  List<_QAItem> get _filteredQuestions {
    if (_selectedFilter == 'All') return _questions;
    return _questions.where((q) => q.category == _selectedFilter).toList();
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  void _submitQuestion() {
    final text = _questionController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _showAskForm = false;
      _questionController.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Your question has been posted successfully'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
      body: Column(
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
                          selected: false,
                          onSelected: (_) {},
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
              Text('${_questions.length} questions • ${_questions.where((q) => q.isAnswered).length} answered',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
            ]),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: _filters.map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedFilter = filter),
                    selectedColor: secondaryColor,
                    backgroundColor: Colors.grey.shade100,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : Colors.grey.shade700,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                      Text('No questions found', style: TextStyle(color: Colors.grey.shade500)),
                    ]),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    itemCount: _filteredQuestions.length,
                    itemBuilder: (context, index) => _QuestionCard(qa: _filteredQuestions[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final _QAItem qa;
  const _QuestionCard({required this.qa});

  @override
  Widget build(BuildContext context) {
    final secondaryColor = const Color(0xFFEAB308);
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
              backgroundColor: qa.authorColor.withOpacity(0.15),
              child: Text(qa.authorInitial, style: TextStyle(color: qa.authorColor, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(qa.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text('${qa.author} • ${qa.time}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: qa.authorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(qa.category, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: qa.authorColor)),
                ),
              ]),
            ),
            IconButton(
              icon: Icon(
                qa.answers > 0 ? Icons.chat_bubble : Icons.chat_bubble_outline,
                color: qa.answers > 0 ? Colors.green : Colors.grey.shade400,
                size: 18,
              ),
              onPressed: () {},
              tooltip: '${qa.answers} answers',
            ),
          ]),
          const SizedBox(height: 8),
          if (qa.question.isNotEmpty)
            Text(
              qa.question,
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
                  '${qa.answers} Answers',
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
            Text('${qa.votes}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const Spacer(),
            Text('View', style: TextStyle(fontSize: 12, color: Colors.blue.shade600, fontWeight: FontWeight.w600)),
          ]),
        ]),
      ),
    );
  }
}

class _QAItem {
  final int id;
  final String title;
  final String question;
  final String author;
  final String time;
  final String category;
  final int answers;
  final int votes;
  final bool isAnswered;
  final String authorInitial;
  final Color authorColor;
  final List<_Answer> answersList;

  _QAItem({
    required this.id,
    required this.title,
    required this.question,
    required this.author,
    required this.time,
    required this.category,
    required this.answers,
    required this.votes,
    required this.isAnswered,
    required this.authorInitial,
    required this.authorColor,
    required this.answersList,
  });
}

class _Answer {
  final String author;
  final String time;
  final String body;
  final int votes;
  final bool isAccepted;

  _Answer({
    required this.author,
    required this.time,
    required this.body,
    required this.votes,
    required this.isAccepted,
  });
}