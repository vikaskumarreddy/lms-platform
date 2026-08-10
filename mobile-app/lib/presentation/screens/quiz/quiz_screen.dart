import 'package:flutter/material.dart';
import '../../../core/widgets/common_header.dart';

class QuizScreen extends StatefulWidget {
  final int lessonId;
  const QuizScreen({super.key, required this.lessonId});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _currentQuestion = 0;
  int? _selectedAnswer;
  bool _isAnswered = false;
  int _score = 0;
  bool _quizCompleted = false;

  final List<_Question> _questions = [
    _Question(
      id: 1,
      question: 'What is the correct way to create a stream in Java?',
      options: ['list.stream()', 'createStream(list)', 'new Stream(list)', 'Stream.of(list)'],
      correctAnswer: 0,
    ),
    _Question(
      id: 2,
      question: 'Which method is used to filter elements in a stream?',
      options: ['filter()', 'map()', 'reduce()', 'collect()'],
      correctAnswer: 0,
    ),
    _Question(
      id: 3,
      question: 'What does the map() function do in streams?',
      options: ['Filters elements', 'Transforms elements', 'Reduces elements', 'Sorts elements'],
      correctAnswer: 1,
    ),
    _Question(
      id: 4,
      question: 'Which of these is NOT a terminal operation?',
      options: ['forEach()', 'filter()', 'collect()', 'reduce()'],
      correctAnswer: 1,
    ),
    _Question(
      id: 5,
      question: 'What is the return type of the collect() method?',
      options: ['Stream', 'Optional', 'List/R Collection', 'Boolean'],
      correctAnswer: 2,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF0F172A);
    final secondaryColor = const Color(0xFFEAB308);

    if (_quizCompleted) {
      return Scaffold(
        appBar: const CommonHeader(showBackButton: true, title: 'Quiz Result'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emoji_events, size: 80, color: _score >= 3 ? Colors.green : Colors.orange),
                const SizedBox(height: 24),
                Text('Quiz Completed!', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: primaryColor)),
                const SizedBox(height: 16),
                Text('Your Score', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                Text('$_score / ${_questions.length}', style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold, color: secondaryColor)),
                const SizedBox(height: 8),
                Text('${((_score / _questions.length) * 100).toInt()}%', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _currentQuestion = 0;
                        _selectedAnswer = null;
                        _isAnswered = false;
                        _score = 0;
                        _quizCompleted = false;
                      });
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: primaryColor, padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: const Text('Retry Quiz'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final question = _questions[_currentQuestion];

    return Scaffold(
      appBar: CommonHeader(showBackButton: true, title: 'Quiz - Lesson ${widget.lessonId}'),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade50,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Question ${_currentQuestion + 1}/${_questions.length}', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                    Text('Score: $_score', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: secondaryColor)),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (_currentQuestion + 1) / _questions.length,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(secondaryColor),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(question.question, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: primaryColor)),
                  const SizedBox(height: 24),
                  Expanded(
                    child: ListView.builder(
                      itemCount: question.options.length,
                      itemBuilder: (context, index) {
                        final isSelected = _selectedAnswer == index;
                        final isCorrect = index == question.correctAnswer;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          color: _isAnswered
                              ? isCorrect
                                  ? Colors.green.withOpacity(0.1)
                                  : isSelected
                                      ? Colors.red.withOpacity(0.1)
                                      : null
                              : null,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: _isAnswered
                                  ? isCorrect
                                      ? Colors.green
                                      : isSelected
                                          ? Colors.red
                                          : Colors.transparent
                                  : isSelected
                                      ? secondaryColor
                                      : Colors.grey.shade300,
                              width: 2,
                            ),
                          ),
                          child: ListTile(
                            title: Text(question.options[index]),
                            trailing: _isAnswered
                                ? Icon(
                                    isCorrect ? Icons.check_circle : isSelected ? Icons.cancel : null,
                                    color: isCorrect ? Colors.green : isSelected ? Colors.red : null,
                                  )
                                : null,
                            onTap: _isAnswered
                                ? null
                                : () {
                                    setState(() {
                                      _selectedAnswer = index;
                                      _isAnswered = true;
                                      if (index == question.correctAnswer) {
                                        _score++;
                                      }
                                    });
                                  },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isAnswered)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_currentQuestion < _questions.length - 1) {
                      setState(() {
                        _currentQuestion++;
                        _selectedAnswer = null;
                        _isAnswered = false;
                      });
                    } else {
                      setState(() => _quizCompleted = true);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: primaryColor, padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: Text(_currentQuestion < _questions.length - 1 ? 'Next Question' : 'Finish Quiz'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Question {
  final int id;
  final String question;
  final List<String> options;
  final int correctAnswer;

  _Question({
    required this.id,
    required this.question,
    required this.options,
    required this.correctAnswer,
  });
}