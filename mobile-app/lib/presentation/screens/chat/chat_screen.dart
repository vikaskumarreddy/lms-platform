import 'package:flutter/material.dart';
import '../../../core/widgets/common_header.dart';

class ChatScreen extends StatefulWidget {
  final int mentorId;
  const ChatScreen({super.key, required this.mentorId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<_ChatMessage> _messages = [
    _ChatMessage(sender: 'mentor', text: 'Hello! How can I help you today?', time: '10:00 AM'),
    _ChatMessage(sender: 'student', text: 'I have a doubt about Java streams.', time: '10:05 AM'),
    _ChatMessage(sender: 'mentor', text: 'Sure, what specifically do you need help with?', time: '10:06 AM'),
    _ChatMessage(sender: 'student', text: 'How to use filter() and map() together?', time: '10:07 AM'),
    _ChatMessage(sender: 'mentor', text: 'Great question! You can chain them. For example: list.stream().filter(...).map(...).collect(...)', time: '10:10 AM'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonHeader(showBackButton: true, title: 'Mentor Chat'),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isStudent = message.sender == 'student';
                return Align(
                  alignment: isStudent ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isStudent ? const Color(0xFF0F172A) : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(message.text, style: TextStyle(color: isStudent ? Colors.white : Colors.black)),
                        const SizedBox(height: 4),
                        Text(message.time, style: TextStyle(fontSize: 10, color: isStudent ? Colors.white70 : Colors.grey.shade600)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200))),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFF0F172A),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: () {
                      if (_messageController.text.trim().isNotEmpty) {
                        setState(() {
                          _messages.add(_ChatMessage(
                            sender: 'student',
                            text: _messageController.text.trim(),
                            time: '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                          ));
                          _messageController.clear();
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String sender;
  final String text;
  final String time;
  _ChatMessage({required this.sender, required this.text, required this.time});
}