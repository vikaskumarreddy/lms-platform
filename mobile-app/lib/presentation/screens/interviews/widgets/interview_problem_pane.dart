import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';

/// Problem description & prompt pane for 1-on-1 interviews.
/// Displays question criteria, examples, constraints, and allows
/// quick problem switching from the curated question bank.
class InterviewProblemPane extends StatelessWidget {
  final String title;
  final String difficulty;
  final String? category;
  final String description;
  final List<Map<String, dynamic>> availableQuestions;
  final ValueChanged<Map<String, dynamic>> onSelectQuestion;

  const InterviewProblemPane({
    super.key,
    required this.title,
    required this.difficulty,
    this.category,
    required this.description,
    this.availableQuestions = const [],
    required this.onSelectQuestion,
  });

  Color _difficultyColor(String diff) {
    switch (diff.toLowerCase()) {
      case 'easy':
        return const Color(0xFF10B981);
      case 'medium':
        return const Color(0xFFF59E0B);
      case 'hard':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF27D9D3);
    }
  }

  @override
  Widget build(BuildContext context) {
    final diffColor = _difficultyColor(difficulty);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1726),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Problem Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF111E33),
                border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: diffColor.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: diffColor.withOpacity(0.4)),
                              ),
                              child: Text(
                                difficulty.toUpperCase(),
                                style: GoogleFonts.inter(
                                  color: diffColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            if (category != null && category!.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text(
                                category!,
                                style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title.isNotEmpty ? title : 'Coding Challenge',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Switch Problem Action
                  if (availableQuestions.isNotEmpty)
                    PopupMenuButton<Map<String, dynamic>>(
                      tooltip: 'Change Problem',
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: const Icon(Icons.swap_horiz, color: Color(0xFF27D9D3), size: 18),
                      ),
                      color: const Color(0xFF161F30),
                      onSelected: onSelectQuestion,
                      itemBuilder: (context) {
                        return availableQuestions.map((q) {
                          final qTitle = (q['title'] as String?) ?? 'Problem';
                          final qDiff = (q['difficulty'] as String?) ?? 'Medium';
                          final color = _difficultyColor(qDiff);
                          return PopupMenuItem(
                            value: q,
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    qTitle,
                                    style: GoogleFonts.inter(color: Colors.white, fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  qDiff,
                                  style: GoogleFonts.inter(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          );
                        }).toList();
                      },
                    ),
                ],
              ),
            ),

            // Problem Markdown Statement
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: MarkdownBody(
                  data: description.isNotEmpty
                      ? description
                      : '### Problem Description\n\nNo detailed problem statement provided for this session.',
                  selectable: true,
                  styleSheet: MarkdownStyleSheet(
                    p: GoogleFonts.inter(color: const Color(0xFFCBD5E1), fontSize: 13, height: 1.6),
                    h1: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    h2: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    h3: GoogleFonts.outfit(color: const Color(0xFF27D9D3), fontSize: 14, fontWeight: FontWeight.w600),
                    code: GoogleFonts.firaCode(
                      backgroundColor: const Color(0xFF1E293B),
                      color: const Color(0xFF38BDF8),
                      fontSize: 12,
                    ),
                    codeblockDecoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    blockquoteDecoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withOpacity(0.5),
                      borderRadius: BorderRadius.circular(6),
                      border: const Border(left: BorderSide(color: Color(0xFF27D9D3), width: 3)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
