import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lms_student_app/presentation/screens/interviews/widgets/interview_video_pane.dart';
import 'package:lms_student_app/presentation/screens/interviews/widgets/interview_code_editor_pane.dart';
import 'package:lms_student_app/presentation/screens/interviews/widgets/interview_problem_pane.dart';
import 'package:lms_student_app/presentation/screens/interviews/widgets/interview_evaluation_pane.dart';

void main() {
  testWidgets('InterviewProblemPane displays title, difficulty, and description', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InterviewProblemPane(
            title: 'Two Sum Problem',
            difficulty: 'Easy',
            category: 'Algorithms',
            description: 'Find two numbers that add to target.',
            availableQuestions: const [],
            onSelectQuestion: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Two Sum Problem'), findsOneWidget);
    expect(find.text('EASY'), findsOneWidget);
    expect(find.text('Algorithms'), findsOneWidget);
  });

  testWidgets('InterviewEvaluationPane renders rubric ratings and hiring decisions', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InterviewEvaluationPane(
            roomCode: 'TEST-ROOM-123',
            candidateName: 'John Doe',
            onSubmit: (_) async => true,
          ),
        ),
      ),
    );

    expect(find.text('Interviewer Rubric'), findsOneWidget);
    expect(find.text('John Doe'), findsOneWidget);
    expect(find.text('Problem Solving & DSA'), findsOneWidget);
    expect(find.text('Technical & Language Proficiency'), findsOneWidget);
    expect(find.text('Hiring Recommendation'), findsOneWidget);
    expect(find.text('Strong Hire'), findsOneWidget);
    expect(find.text('Save Draft'), findsOneWidget);
  });

  testWidgets('InterviewCodeEditorPane displays language selector and Run Code button', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InterviewCodeEditorPane(
            roomCode: 'TEST-ROOM-123',
            initialLanguage: 'java',
            initialCode: 'class Solution {}',
            onRunCode: (_, __, ___) async => {'status': 'SUCCESS', 'output': 'Passed!'},
          ),
        ),
      ),
    );

    expect(find.text('Java 21'), findsOneWidget);
    expect(find.text('Run Code'), findsOneWidget);
  });

  testWidgets('InterviewVideoPane initializes WebRTC video call pane', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InterviewVideoPane(
            roomCode: 'AXIS-INT-101',
            candidateName: 'Jane Candidate',
            interviewerName: 'Dr. Mentor',
            isInterviewer: true,
            onLeaveCall: () {},
          ),
        ),
      ),
    );

    expect(find.text('Initializing WebRTC Camera & Mic...'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });
}
