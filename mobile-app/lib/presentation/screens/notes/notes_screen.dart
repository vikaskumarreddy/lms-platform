import 'package:flutter/material.dart';
import '../../../core/widgets/common_header.dart';

class NotesScreen extends StatelessWidget {
  final int lessonId; const NotesScreen({super.key, required this.lessonId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonHeader(showBackButton: true, title: 'Notes'),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.note, size: 64, color: Color(0xFFEAB308)),
            const SizedBox(height: 16),
            Text('NotesScreen', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text('Coming Soon', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

