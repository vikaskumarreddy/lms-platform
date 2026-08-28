import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/common_header.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final ApiService _api = ApiService();
  String _selectedType = 'General';
  final TextEditingController _feedbackController = TextEditingController();
  int _rating = 0;
  bool _submitting = false;
  List<Map<String, dynamic>> _myFeedback = [];
  bool _loadingFeedback = true;

  @override
  void initState() {
    super.initState();
    _loadMyFeedback();
  }

  Future<void> _loadMyFeedback() async {
    final feedback = await _api.getMyFeedback();
    if (!mounted) return;
    setState(() {
      _myFeedback = feedback;
      _loadingFeedback = false;
    });
  }

  Future<void> _handleSubmit() async {
    if (_feedbackController.text.trim().isEmpty || _rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide rating and feedback')),
      );
      return;
    }

    setState(() => _submitting = true);
    final success = await _api.submitFeedback(
      type: _selectedType,
      rating: _rating,
      comment: _feedbackController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thank you for your feedback!')),
      );
      _feedbackController.clear();
      setState(() {
        _rating = 0;
        _selectedType = 'General';
      });
      _loadMyFeedback();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit feedback. Please try again.')),
      );
    }
  }

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
                        onPressed: _submitting ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                        child: _submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Submit Feedback'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Recent Feedback', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: primaryColor)),
            const SizedBox(height: 12),
            if (_loadingFeedback)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_myFeedback.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'You haven\'t submitted any feedback yet.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _myFeedback.length,
                itemBuilder: (context, index) {
                  final item = _myFeedback[index];
                  final rating = (item['rating'] as num?)?.toInt() ?? 0;
                  final type = (item['type'] as String?) ?? 'General';
                  final comment = (item['comment'] as String?) ?? '';
                  final createdAt = (item['createdAt'] as String?) ?? '';
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
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(type, style: TextStyle(fontSize: 11, color: primaryColor, fontWeight: FontWeight.bold)),
                              ),
                              if (createdAt.isNotEmpty)
                                Text(createdAt, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: List.generate(5, (i) {
                              return Icon(Icons.star, size: 16, color: i < rating ? secondaryColor : Colors.grey.shade300);
                            }),
                          ),
                          if (comment.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(comment, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                          ],
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