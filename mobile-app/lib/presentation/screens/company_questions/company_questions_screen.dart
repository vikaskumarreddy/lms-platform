import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/api_service.dart';
import '../../../core/widgets/common_header.dart';
import '../browser/in_app_browser_screen.dart';
import 'company_questions_view_screen.dart';

const Color _kInk = Color(0xFF0F172A);
const Color _kAccent = Color(0xFFEAB308);
const Color _kMuted = Color(0xFF64748B);

/// Company-specific interview-prep tiles: CONTENT tiles open the read-only Q&A
/// guide ([CompanyQuestionsViewScreen]) where the student reads each question
/// with its answer; PDF tiles open in the existing embedded browser.
class CompanyQuestionsScreen extends StatefulWidget {
  const CompanyQuestionsScreen({super.key});

  @override
  State<CompanyQuestionsScreen> createState() => _CompanyQuestionsScreenState();
}

class _CompanyQuestionsScreenState extends State<CompanyQuestionsScreen> {
  final ApiService _api = ApiService();

  bool _loading = true;
  String? _error;
  int? _userId;
  List<Map<String, dynamic>> _kits = [];
  String _search = '';
  bool _favoritesOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('userId');
    if (userId == null) {
      setState(() {
        _loading = false;
        _error = 'Please log in again to view company questions.';
      });
      return;
    }
    _userId = userId;
    final kits = await _api.getCompanyKits(userId);
    setState(() {
      _kits = kits;
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _filtered {
    return _kits.where((kit) {
      if (_favoritesOnly && kit['isFavorite'] != true) return false;
      if (_search.trim().isEmpty) return true;
      final q = _search.trim().toLowerCase();
      final name = (kit['companyName'] as String? ?? '').toLowerCase();
      final tags = (kit['tags'] as String? ?? '').toLowerCase();
      return name.contains(q) || tags.contains(q);
    }).toList();
  }

  Future<void> _toggleFavorite(Map<String, dynamic> kit) async {
    final userId = _userId;
    if (userId == null) return;
    final kitId = (kit['id'] as num).toInt();
    final result = await _api.toggleCompanyKitFavorite(studentId: userId, kitId: kitId);
    if (result == null || !mounted) return;
    setState(() => kit['isFavorite'] = result);
  }

  Future<void> _openKit(Map<String, dynamic> kit) async {
    final mode = kit['mode'] as String? ?? 'CONTENT';
    final companyName = kit['companyName'] as String? ?? 'Company';
    if (mode == 'PDF') {
      final url = kit['pdfUrl'] as String?;
      if (url == null || url.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No PDF has been added for this company yet.')),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => InAppBrowserScreen(url: url, title: companyName)),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CompanyQuestionsViewScreen(
          assessmentId: (kit['id'] as num).toInt(),
          companyName: companyName,
          companyDescription: kit['description'] as String?,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: const CommonHeader(title: 'Company Questions'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: Column(
                    children: [
                      _buildSearchAndFilter(),
                      Expanded(child: _buildList()),
                    ],
                  ),
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.business_outlined, size: 56, color: _kMuted),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: _kMuted)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(backgroundColor: _kInk, foregroundColor: Colors.white),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Search company or tag...',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: !_favoritesOnly,
                onSelected: (_) => setState(() => _favoritesOnly = false),
                selectedColor: _kAccent,
                labelStyle: TextStyle(color: !_favoritesOnly ? Colors.black : Colors.grey.shade700),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Favorites'),
                selected: _favoritesOnly,
                onSelected: (_) => setState(() => _favoritesOnly = true),
                selectedColor: _kAccent,
                labelStyle: TextStyle(color: _favoritesOnly ? Colors.black : Colors.grey.shade700),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildList() {
    final kits = _filtered;
    if (kits.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Icon(Icons.business_outlined, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _favoritesOnly ? 'No favorites yet' : 'No company questions available yet',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: kits.length,
      itemBuilder: (context, index) => _kitCard(kits[index]),
    );
  }

  Widget _kitCard(Map<String, dynamic> kit) {
    final companyName = kit['companyName'] as String? ?? 'Company';
    final mode = kit['mode'] as String? ?? 'CONTENT';
    final tags = (kit['tags'] as String? ?? '')
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    final description = kit['description'] as String?;
    final isFavorite = kit['isFavorite'] == true;
    final logoUrl = kit['logoUrl'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openKit(kit),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: _kInk.withOpacity(0.08),
                    backgroundImage: (logoUrl != null && logoUrl.trim().isNotEmpty)
                        ? NetworkImage(logoUrl)
                        : null,
                    child: (logoUrl == null || logoUrl.trim().isEmpty)
                        ? Text(
                            companyName.isNotEmpty ? companyName[0].toUpperCase() : '?',
                            style: const TextStyle(fontWeight: FontWeight.w700, color: _kInk),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(companyName,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kInk)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _pill(mode == 'PDF' ? 'PDF' : 'Practice set',
                                mode == 'PDF' ? const Color(0xFF7C3AED) : const Color(0xFF0D9488)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => _toggleFavorite(kit),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                        color: isFavorite ? _kAccent : _kMuted,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
              if (description != null && description.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: _kMuted, height: 1.35),
                ),
              ],
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: tags.map((t) => _pill(t, _kMuted)).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
