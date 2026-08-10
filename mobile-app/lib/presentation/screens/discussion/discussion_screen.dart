import 'package:flutter/material.dart';
import '../../../core/widgets/common_header.dart';

class DiscussionScreen extends StatefulWidget {
  final int lessonId;
  const DiscussionScreen({super.key, required this.lessonId});

  @override
  State<DiscussionScreen> createState() => _DiscussionScreenState();
}

class _DiscussionScreenState extends State<DiscussionScreen> {
  String _selectedFilter = 'All';
  final TextEditingController _commentController = TextEditingController();
  final List<_CommentItem> _comments = [
    _CommentItem(id: 1, author: 'Rahul Kumar', text: 'Can someone explain this concept again?', time: '2 hours ago', likes: 5, replies: 2),
    _CommentItem(id: 2, author: 'Priya Sharma', text: 'Great explanation! Very helpful.', time: '5 hours ago', likes: 12, replies: 0),
    _CommentItem(id: 3, author: 'Arjun Nair', text: 'I have a doubt about the implementation.', time: '1 day ago', likes: 3, replies: 1),
    _CommentItem(id: 4, author: 'Sneha Reddy', text: 'This helped me a lot. Thank you!', time: '2 days ago', likes: 8, replies: 0),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonHeader(title: 'Discussion - Lesson ${widget.lessonId}'),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.grey.shade50),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      prefixIcon: const Icon(Icons.comment, size: 20),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: ['All', 'Questions', 'Praise', 'General'].map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedFilter = filter),
                    selectedColor: const Color(0xFFEAB308),
                    backgroundColor: Colors.grey.shade100,
                    labelStyle: TextStyle(color: isSelected ? Colors.black : Colors.grey.shade700),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _comments.length,
              itemBuilder: (context, index) {
                final comment = _comments[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.blue.withOpacity(0.1),
                              child: Text(comment.author[0], style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(comment.author, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text(comment.time, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(comment.text, style: const TextStyle(fontSize: 14)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () {},
                              icon: Icon(Icons.thumb_up_outlined, size: 18, color: Colors.grey.shade600),
                            ),
                            Text('${comment.likes}', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                            const SizedBox(width: 16),
                            IconButton(
                              onPressed: () {},
                              icon: Icon(Icons.comment_outlined, size: 18, color: Colors.grey.shade600),
                            ),
                            Text('${comment.replies}', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                            const SizedBox(width: 16),
                            IconButton(
                              onPressed: () {},
                              icon: Icon(Icons.share_outlined, size: 18, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentItem {
  final int id;
  final String author;
  final String text;
  final String time;
  final int likes;
  final int replies;

  _CommentItem({
    required this.id,
    required this.author,
    required this.text,
    required this.time,
    required this.likes,
    required this.replies,
  });
}