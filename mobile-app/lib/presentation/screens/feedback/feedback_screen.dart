import 'package:flutter/material.dart';
import '../../../core/widgets/common_header.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  String _selectedType = 'General';
  final TextEditingController _feedbackController = TextEditingController();
  int _rating = 0;

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF0F172A);
    final secondaryColor = const Color(0xFFEAB308);

    return Scaffold(
      appBar: const CommonHeader(title: 'Feedback'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Submit Feedback', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: primaryColor)),
                    const SizedBox(height: 16),
                    const Text('Feedback Type', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['General', 'Bug', 'Feature', 'Course', 'Instructor'].map((type) {
                        final isSelected = _selectedType == type;
                        return ChoiceChip(
                          label: Text(type),
                          selected: isSelected,
                          onSelected: (_) => setState(() => _selectedType = type),
                          selectedColor: secondaryColor,
                          backgroundColor: Colors.grey.shade100,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text('Your Rating', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(5, (index) {
                        return IconButton(
                          onPressed: () => setState(() => _rating = index + 1),
                          icon: Icon(
                            index < _rating ? Icons.star : Icons.star_border,
                            color: secondaryColor,
                            size: 32,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    const Text('Your Feedback', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _feedbackController,
                      maxLines: 6,
                      decoration: InputDecoration(
                        hintText: 'Tell us what you think...',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_feedbackController.text.trim().isNotEmpty && _rating > 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Thank you for your feedback!')),
                            );
                            _feedbackController.clear();
                            setState(() {
                              _rating = 0;
                              _selectedType = 'General';
                            });
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please provide rating and feedback')),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                        child: const Text('Submit Feedback'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Recent Feedback', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: primaryColor)),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 3,
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Feedback #${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: index == 0 ? Colors.blue.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(index == 0 ? 'In Review' : 'Resolved', style: TextStyle(fontSize: 11, color: index == 0 ? Colors.blue : Colors.green, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: List.generate(5, (i) {
                            return Icon(Icons.star, size: 16, color: i < 4 ? secondaryColor : Colors.grey.shade300);
                          }),
                        ),
                        const SizedBox(height: 8),
                        Text('Great course! The content is well-structured and easy to follow.', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                        const SizedBox(height: 4),
                        Text('Submitted on 10 Jan 2026', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}