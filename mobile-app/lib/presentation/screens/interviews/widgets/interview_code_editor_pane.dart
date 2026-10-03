import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lms_student_app/core/services/api_service.dart';

/// Syntax highlighter controller that tokenizes and colors code in real-time
/// without requiring heavy external dependencies.
class SyntaxHighlighterEditingController extends TextEditingController {
  String language;

  SyntaxHighlighterEditingController({super.text, required this.language});

  static final _keywordsJavaCppJs = RegExp(
    r'\b(public|private|protected|class|interface|enum|extends|implements|static|final|const|let|var|function|def|return|if|else|switch|case|default|for|while|do|break|continue|try|catch|finally|throw|throws|new|this|super|import|package|void|int|boolean|double|float|char|long|short|byte|true|false|null|undefined|async|await|lambda|from|as|with|yield|pass|in|is|not|and|or)\b',
  );

  static final _keywordsSql = RegExp(
    r'\b(SELECT|FROM|WHERE|INSERT|INTO|UPDATE|DELETE|JOIN|LEFT|RIGHT|INNER|OUTER|ON|GROUP|BY|ORDER|HAVING|LIMIT|OFFSET|CREATE|TABLE|ALTER|DROP|INDEX|PRIMARY|KEY|FOREIGN|REFERENCES|NOT|NULL|AND|OR|AS|IN|EXISTS|BETWEEN|LIKE|UNION|ALL|DISTINCT|CASE|WHEN|THEN|ELSE|END)\b',
    caseSensitive: false,
  );

  static final _typesPattern = RegExp(
    r'\b(String|Integer|Double|Boolean|List|Map|Set|HashMap|ArrayList|Arrays|Collections|Math|System|Console|Object|vector|string|cin|cout|endl|Number|Promise|Record)\b',
  );

  static final _stringsPattern = RegExp(r'("(?:[^"\\]|\\.)*"|' r"'(?:[^'\\]|\\.)*')");
  static final _numbersPattern = RegExp(r'\b\d+(?:\.\d+)?\b');
  static final _commentsPattern = RegExp(r'(//.*|#.*|--.*|/\*[\s\S]*?\*/)');
  static final _methodPattern = RegExp(r'\b([a-zA-Z_][a-zA-Z0-9_]*)(?=\s*\()');

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final text = this.text;
    if (text.isEmpty) {
      return TextSpan(style: style, text: '');
    }

    final baseStyle = style ??
        GoogleFonts.firaCode(
          color: const Color(0xFFF1F5F9),
          fontSize: 13,
          height: 1.5,
        );

    final isSql = language.toLowerCase() == 'sql';
    final keywordRegex = isSql ? _keywordsSql : _keywordsJavaCppJs;

    // Combined pattern with named match groups
    final pattern = RegExp(
      '(${_commentsPattern.pattern})|(${_stringsPattern.pattern})|(${keywordRegex.pattern})|(${_typesPattern.pattern})|(${_numbersPattern.pattern})|(${_methodPattern.pattern})',
      multiLine: true,
      caseSensitive: !isSql,
    );

    final spans = <TextSpan>[];
    int lastIndex = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: baseStyle.copyWith(color: const Color(0xFFE2E8F0)),
        ));
      }

      final matchedText = match.group(0)!;

      if (_commentsPattern.hasMatch(matchedText)) {
        spans.add(TextSpan(
          text: matchedText,
          style: baseStyle.copyWith(
            color: const Color(0xFF94A3B8),
            fontStyle: FontStyle.italic,
          ),
        ));
      } else if (_stringsPattern.hasMatch(matchedText)) {
        spans.add(TextSpan(
          text: matchedText,
          style: baseStyle.copyWith(color: const Color(0xFF4ADE80)), // Spring Green
        ));
      } else if (keywordRegex.hasMatch(matchedText)) {
        spans.add(TextSpan(
          text: matchedText,
          style: baseStyle.copyWith(
            color: const Color(0xFFF472B6), // Coral / Pink
            fontWeight: FontWeight.w600,
          ),
        ));
      } else if (_typesPattern.hasMatch(matchedText)) {
        spans.add(TextSpan(
          text: matchedText,
          style: baseStyle.copyWith(
            color: const Color(0xFF38BDF8), // Cyan / Sky Blue
            fontWeight: FontWeight.w600,
          ),
        ));
      } else if (_numbersPattern.hasMatch(matchedText)) {
        spans.add(TextSpan(
          text: matchedText,
          style: baseStyle.copyWith(color: const Color(0xFFFB923C)), // Amber / Orange
        ));
      } else if (_methodPattern.hasMatch(matchedText)) {
        spans.add(TextSpan(
          text: matchedText,
          style: baseStyle.copyWith(color: const Color(0xFFC084FC)), // Lilac / Purple
        ));
      } else {
        spans.add(TextSpan(
          text: matchedText,
          style: baseStyle.copyWith(color: const Color(0xFFE2E8F0)),
        ));
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: baseStyle.copyWith(color: const Color(0xFFE2E8F0)),
      ));
    }

    return TextSpan(style: baseStyle, children: spans);
  }
}

/// Collaborative Code Editor Pane for 1-on-1 Interviews.
/// Supports multi-language editing, syntax styling, line numbers,
/// real-time code execution, stdin custom input, and terminal output.
class InterviewCodeEditorPane extends StatefulWidget {
  final String roomCode;
  final String initialLanguage;
  final String initialCode;
  final Future<Map<String, dynamic>?> Function(String language, String code, String? input) onRunCode;

  const InterviewCodeEditorPane({
    super.key,
    required this.roomCode,
    this.initialLanguage = 'java',
    this.initialCode = '',
    required this.onRunCode,
  });

  @override
  State<InterviewCodeEditorPane> createState() => _InterviewCodeEditorPaneState();
}

class _InterviewCodeEditorPaneState extends State<InterviewCodeEditorPane> with SingleTickerProviderStateMixin {
  late SyntaxHighlighterEditingController _codeController;
  late TextEditingController _inputController;
  late TabController _bottomTabController;

  final ApiService _api = ApiService();
  Timer? _codeSyncPollTimer;
  Timer? _debounceTimer;
  int _lastSelfEditTimestamp = 0;

  String _selectedLanguage = 'java';
  bool _isRunning = false;
  String _consoleOutput = 'Click "Run Code" to compile and execute your solution.';
  String _consoleError = '';
  String _executionStatus = '';
  int _executionTimeMs = 0;
  bool _isConsoleOpen = true;

  final Map<String, String> _languageTemplates = {
    'java': '''import java.util.*;

public class Solution {
    public static void main(String[] args) {
        System.out.println("Hello, 100ms Interview Room!");
        // Write your solution logic here
    }
}
''',
    'python': '''def solve():
    print("Hello, 100ms Interview Room!")
    # Write your solution logic here

if __name__ == '__main__':
    solve()
''',
    'cpp': '''#include <iostream>
#include <vector>
using namespace std;

int main() {
    cout << "Hello, 100ms Interview Room!" << endl;
    return 0;
}
''',
    'javascript': '''function solution() {
    console.log("Hello, 100ms Interview Room!");
}

solution();
''',
    'sql': '''-- Write your SQL query statement below
SELECT *
FROM employees
WHERE salary > 50000;
''',
  };

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.initialLanguage.isNotEmpty ? widget.initialLanguage.toLowerCase() : 'java';
    _codeController = SyntaxHighlighterEditingController(
      text: widget.initialCode.isNotEmpty ? widget.initialCode : (_languageTemplates[_selectedLanguage] ?? ''),
      language: _selectedLanguage,
    );
    _inputController = TextEditingController();
    _bottomTabController = TabController(length: 2, vsync: this);

    _codeController.addListener(_onCodeChanged);
    _codeSyncPollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollRemoteCode());
  }

  void _onCodeChanged() {
    _lastSelfEditTimestamp = DateTime.now().millisecondsSinceEpoch;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1500), () {
      _api.syncInterviewCode(widget.roomCode, code: _codeController.text, language: _selectedLanguage);
    });
  }

  Future<void> _pollRemoteCode() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastSelfEditTimestamp < 3000) return; // Don't interrupt while active typing

    final remote = await _api.getSyncedInterviewCode(widget.roomCode);
    if (!mounted || remote == null) return;
    final remoteCode = remote['code'] as String?;
    final remoteLang = remote['language'] as String?;

    if (remoteCode != null && remoteCode.isNotEmpty && remoteCode != _codeController.text) {
      final prevCursor = _codeController.selection;
      _codeController.removeListener(_onCodeChanged);
      _codeController.text = remoteCode;
      _codeController.addListener(_onCodeChanged);
      if (prevCursor.start <= remoteCode.length) {
        _codeController.selection = prevCursor;
      }
      if (remoteLang != null && remoteLang.isNotEmpty && remoteLang != _selectedLanguage) {
        setState(() {
          _selectedLanguage = remoteLang;
          _codeController.language = remoteLang;
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant InterviewCodeEditorPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCode.isNotEmpty && widget.initialCode != oldWidget.initialCode && _codeController.text.isEmpty) {
      _codeController.text = widget.initialCode;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _codeSyncPollTimer?.cancel();
    _codeController.removeListener(_onCodeChanged);
    _codeController.dispose();
    _inputController.dispose();
    _bottomTabController.dispose();
    super.dispose();
  }

  void _onLanguageChanged(String? newLang) {
    if (newLang == null || newLang == _selectedLanguage) return;
    setState(() {
      _selectedLanguage = newLang;
      _codeController.language = newLang;
      if (_codeController.text.trim().isEmpty ||
          _codeController.text == _languageTemplates['java'] ||
          _codeController.text == _languageTemplates['python']) {
        _codeController.text = _languageTemplates[newLang] ?? '';
      }
    });
  }

  Future<void> _handleRunCode() async {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
      _isConsoleOpen = true;
      _consoleOutput = 'Compiling and executing on server...';
      _consoleError = '';
      _executionStatus = 'RUNNING';
    });

    final stopwatch = Stopwatch()..start();

    try {
      final res = await widget.onRunCode(
        _selectedLanguage,
        _codeController.text,
        _inputController.text,
      );

      stopwatch.stop();

      if (mounted) {
        setState(() {
          _isRunning = false;
          _executionTimeMs = stopwatch.elapsedMilliseconds;
          if (res != null) {
            _consoleOutput = (res['output'] as String?) ?? '';
            _consoleError = (res['error'] as String?) ?? '';
            final status = (res['status'] as String?) ?? 'SUCCESS';
            _executionStatus = status.toUpperCase();
            if (_consoleOutput.isEmpty && _consoleError.isEmpty) {
              _consoleOutput = 'Process exited with code 0 (no standard output).';
            }
          } else {
            _consoleOutput = 'Execution finished with no output returned.';
            _executionStatus = 'FINISHED';
          }
        });
      }
    } catch (e) {
      stopwatch.stop();
      if (mounted) {
        setState(() {
          _isRunning = false;
          _executionTimeMs = stopwatch.elapsedMilliseconds;
          _consoleError = 'Execution error: $e';
          _executionStatus = 'ERROR';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1526), // Axisora Dark IDE Canvas
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            // Top Toolbar: Language Selector + Actions
            _buildEditorToolbar(),

            // Code Editor Canvas (with line numbers gutter)
            Expanded(
              child: _buildCodeEditorCanvas(),
            ),

            // Bottom Console Drawer (Collapsible)
            if (_isConsoleOpen) _buildBottomConsoleDrawer(),
          ],
        ),
      ),
    );
  }

  Widget _buildEditorToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF131D32),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Row(
        children: [
          // Language Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2B45),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedLanguage,
                dropdownColor: const Color(0xFF131D32),
                icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF27D9D3), size: 18),
                style: GoogleFonts.firaCode(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                onChanged: _onLanguageChanged,
                items: const [
                  DropdownMenuItem(value: 'java', child: Text('Java 21')),
                  DropdownMenuItem(value: 'python', child: Text('Python 3.11')),
                  DropdownMenuItem(value: 'cpp', child: Text('C++ (GCC)')),
                  DropdownMenuItem(value: 'javascript', child: Text('JavaScript (Node)')),
                  DropdownMenuItem(value: 'sql', child: Text('PostgreSQL / SQL')),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Reset Starter Template Button
          IconButton(
            tooltip: 'Reset to starter code',
            icon: const Icon(Icons.refresh, color: Colors.white60, size: 18),
            onPressed: () {
              setState(() {
                _codeController.text = _languageTemplates[_selectedLanguage] ?? '';
              });
            },
          ),

          // Toggle Console Button
          IconButton(
            tooltip: _isConsoleOpen ? 'Hide Console' : 'Show Console',
            icon: Icon(
              _isConsoleOpen ? Icons.terminal : Icons.terminal_outlined,
              color: _isConsoleOpen ? const Color(0xFF27D9D3) : Colors.white60,
              size: 18,
            ),
            onPressed: () => setState(() => _isConsoleOpen = !_isConsoleOpen),
          ),

          const Spacer(),

          // Run Code Button (Primary Call To Action)
          ElevatedButton.icon(
            onPressed: _isRunning ? null : _handleRunCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 2,
            ),
            icon: _isRunning
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.play_arrow, size: 18),
            label: Text(
              _isRunning ? 'Running...' : 'Run Code',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeEditorCanvas() {
    return Container(
      color: const Color(0xFF0B1324), // Explicit Dark IDE Canvas Background
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _codeController,
        builder: (context, value, child) {
          final linesCount = '\n'.allMatches(value.text).length + 1;
          final lineNumbersString = List.generate(linesCount, (i) => '${i + 1}').join('\n');

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Line numbers gutter
              Container(
                width: 44,
                padding: const EdgeInsets.only(top: 14, right: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF070D18),
                  border: Border(right: BorderSide(color: Colors.white.withOpacity(0.08))),
                ),
                child: Text(
                  lineNumbersString,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.firaCode(
                    color: const Color(0xFF64748B),
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),
              ),

              // Code Text Input Field
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  child: TextField(
                    controller: _codeController,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    style: GoogleFonts.firaCode(
                      color: const Color(0xFFF1F5F9), // Crisp white default text
                      fontSize: 13,
                      height: 1.5,
                    ),
                    cursorColor: const Color(0xFF27D9D3),
                    cursorWidth: 2,
                    decoration: const InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: Color(0xFF0B1324), // Explicit Dark Background, NEVER WHITE!
                      hoverColor: Colors.transparent,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBottomConsoleDrawer() {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: const Color(0xFF070D18),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Column(
        children: [
          // Console Header Tabs
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            color: const Color(0xFF131D32),
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    controller: _bottomTabController,
                    isScrollable: true,
                    indicatorColor: const Color(0xFF27D9D3),
                    labelColor: const Color(0xFF27D9D3),
                    unselectedLabelColor: Colors.white60,
                    labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                    tabs: const [
                      Tab(text: 'Terminal Output'),
                      Tab(text: 'Custom Stdin'),
                    ],
                  ),
                ),

                // Status Badge
                if (_executionStatus.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _executionStatus == 'SUCCESS'
                          ? Colors.green.withOpacity(0.2)
                          : Colors.redAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _executionStatus == 'SUCCESS' ? Colors.green : Colors.redAccent,
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      '$_executionStatus ${_executionTimeMs > 0 ? "(${_executionTimeMs}ms)" : ""}',
                      style: GoogleFonts.firaCode(
                        fontSize: 10,
                        color: _executionStatus == 'SUCCESS' ? Colors.greenAccent : Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                // Close Drawer Button
                InkWell(
                  onTap: () => setState(() => _isConsoleOpen = false),
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(Icons.close, color: Colors.white54, size: 16),
                  ),
                ),
              ],
            ),
          ),

          // Console Tab Views
          Expanded(
            child: TabBarView(
              controller: _bottomTabController,
              children: [
                // Terminal Output Tab
                Container(
                  padding: const EdgeInsets.all(12),
                  color: const Color(0xFF070D18),
                  width: double.infinity,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_consoleOutput.isNotEmpty)
                          SelectableText(
                            _consoleOutput,
                            style: GoogleFonts.firaCode(
                              color: const Color(0xFFE2E8F0),
                              fontSize: 12,
                              height: 1.45,
                            ),
                          ),
                        if (_consoleError.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          SelectableText(
                            _consoleError,
                            style: GoogleFonts.firaCode(
                              color: const Color(0xFFF87171),
                              fontSize: 12,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Custom Stdin Tab
                Container(
                  padding: const EdgeInsets.all(10),
                  color: const Color(0xFF070D18),
                  child: TextField(
                    controller: _inputController,
                    maxLines: null,
                    style: GoogleFonts.firaCode(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Enter custom test input passed to standard stdin (optional)...',
                      hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 11.5),
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      contentPadding: const EdgeInsets.all(10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                      ),
                    ),
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
