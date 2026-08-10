import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../../core/widgets/common_header.dart';

class CodingPlaygroundScreen extends StatefulWidget {
  final int lessonId;
  const CodingPlaygroundScreen({super.key, required this.lessonId});

  @override
  State<CodingPlaygroundScreen> createState() => _CodingPlaygroundScreenState();
}

class _CodingPlaygroundScreenState extends State<CodingPlaygroundScreen> {
  late final InAppWebViewController _controller;
  String _selectedLanguage = 'Java';
  final TextEditingController _codeController = TextEditingController();
  final List<_CodeSnippet> _savedSnippets = [
    _CodeSnippet(title: 'Hello World', language: 'Java', code: 'System.out.println("Hello World");'),
    _CodeSnippet(title: 'Array Sort', language: 'Java', code: 'Arrays.sort(arr);'),
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonHeader(showBackButton: true, title: 'Coding Playground - Lesson ${widget.lessonId}'),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey.shade50),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Write your code here...',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedLanguage,
                    items: ['Java', 'Python', 'JavaScript', 'C++'].map((lang) => DropdownMenuItem(value: lang, child: Text(lang))).toList(),
                    onChanged: (v) => setState(() => _selectedLanguage = v!),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await _controller.evaluateJavascript(source: _codeController.text.isEmpty ? 'console.log("Hello");' : _codeController.text);
                    },
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Run Code'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text('Save'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    if (_codeController.text.trim().isNotEmpty) {
                      setState(() {
                        _savedSnippets.add(_CodeSnippet(
                          title: 'Snippet ${_savedSnippets.length + 1}',
                          language: _selectedLanguage,
                          code: _codeController.text,
                        ));
                      });
                    }
                  },
                  icon: const Icon(Icons.bookmark_add, size: 18),
                  label: const Text('Save'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEAB308)),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: InAppWebView(
                    initialData: InAppWebViewInitialData(data: _getInitialHTML()),
                    onWebViewCreated: (controller) {
                      _controller = controller;
                    },
                  ),
                ),
                const VerticalDivider(),
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text('Saved Snippets', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _savedSnippets.length,
                          itemBuilder: (context, index) {
                            final snippet = _savedSnippets[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                dense: true,
                                leading: Icon(Icons.code, size: 20, color: Colors.blue),
                                title: Text(snippet.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                subtitle: Text(snippet.language, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                onTap: () {
                                  _codeController.text = snippet.code;
                                  setState(() => _selectedLanguage = snippet.language);
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getInitialHTML() {
    return '''
    <!DOCTYPE html>
    <html>
    <head>
      <style>
        body { background-color: #1E1E1E; color: #D4D4D4; font-family: 'Consolas', monospace; padding: 20px; }
        .output { color: #D4D4D4; white-space: pre-wrap; }
      </style>
    </head>
    <body>
      <div class="output" id="output">// Output will appear here...</div>
      <script>
        function runCode(code) {
          const output = document.getElementById('output');
          try {
            const result = eval(code);
            output.textContent = result !== undefined ? result : 'Code executed successfully';
          } catch (e) {
            output.textContent = 'Error: ' + e.message;
          }
        }
      </script>
    </body>
    </html>
    ''';
  }
}

class _CodeSnippet {
  final String title;
  final String language;
  final String code;

  _CodeSnippet({
    required this.title,
    required this.language,
    required this.code,
  });
}