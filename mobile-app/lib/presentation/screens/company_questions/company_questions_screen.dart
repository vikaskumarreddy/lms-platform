import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/data_providers.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/common_header.dart';
import '../browser/in_app_browser_screen.dart';
import 'company_questions_view_screen.dart';

/// Company-specific interview-prep tiles: CONTENT tiles open the read-only Q&A
/// guide ([CompanyQuestionsViewScreen]) where the student reads each question
/// with its answer; PDF tiles open in the embedded browser.
class CompanyQuestionsScreen extends ConsumerStatefulWidget {
  const CompanyQuestionsScreen({super.key});

  @override
  ConsumerState<CompanyQuestionsScreen> createState() =>
      _CompanyQuestionsScreenState();
}

class _CompanyQuestionsScreenState extends ConsumerState<CompanyQuestionsScreen> {
  static const _bgDark = Color(0xFF071D43);
  static const _cardDark = Color(0xFF0C2B64);
  static const _cyan = Color(0xFF27D9D3);
  static const _amber = Color(0xFFF59E0B);
  static const _purple = Color(0xFF9B5CFF);

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
    try {
      final kits = await _api.getCompanyKits(userId);
      if (!mounted) return;
      setState(() {
        _kits = kits;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load company questions. Please check your connection.';
        _loading = false;
      });
    }
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
    final result =
        await _api.toggleCompanyKitFavorite(studentId: userId, kitId: kitId);
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
          const SnackBar(
              content: Text('No PDF has been added for this company yet.')),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => InAppBrowserScreen(url: url, title: companyName)),
      );
      return;
    }
    final assessmentId =
        (kit['assessmentId'] as num?)?.toInt() ?? (kit['id'] as num?)?.toInt();
    if (assessmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('No questions have been attached to this kit yet.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CompanyQuestionsViewScreen(
          assessmentId: assessmentId,
          companyName: companyName,
          companyDescription: kit['description'] as String?,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CommonHeaderScaffold(
      subtitle: 'Company Questions',
      backgroundColor: _bgDark,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _cyan))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: _cyan,
                  backgroundColor: const Color(0xFF092350),
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
            const Icon(Icons.business_outlined, size: 56, color: Colors.white38),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(
                backgroundColor: _cyan,
                foregroundColor: const Color(0xFF041838),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Try again',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardDark.withOpacity(0.70),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E5BB0).withOpacity(0.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.20),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF104476).withOpacity(0.55),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              cursorColor: _cyan,
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
              decoration: const InputDecoration(
                hintText: 'Search company or tech stack...',
                hintStyle: TextStyle(color: Colors.white54, fontSize: 13),
                prefixIcon:
                    Icon(Icons.search_rounded, color: _cyan, size: 20),
                filled: true,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _filterChip(
                label: 'All Kits',
                selected: !_favoritesOnly,
                onTap: () => setState(() => _favoritesOnly = false),
              ),
              const SizedBox(width: 8),
              _filterChip(
                label: 'Favorites ⭐',
                selected: _favoritesOnly,
                onTap: () => setState(() => _favoritesOnly = true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF104476)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _cyan : Colors.white.withOpacity(0.12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? _cyan : Colors.white70,
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    final kits = _filtered;
    if (kits.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.business_outlined, size: 56, color: Colors.white24),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _favoritesOnly
                  ? 'No favorites saved yet'
                  : 'No company kits available yet',
              style: const TextStyle(color: Colors.white60, fontSize: 14),
            ),
          ),
        ],
      );
    }
    final isNavBarHidden = ref.watch(shellNavBarHiddenProvider);
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 4, 16, isNavBarHidden ? 24 : 90),
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
        color: _cardDark.withOpacity(0.70),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1E5BB0).withOpacity(0.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.20),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openKit(kit),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF104476),
                        border: Border.all(
                            color: const Color(0xFF38BDF8).withOpacity(0.50)),
                      ),
                      alignment: Alignment.center,
                      child: (logoUrl != null && logoUrl.trim().isNotEmpty)
                          ? ClipOval(
                              child: Image.network(
                                logoUrl,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Text(
                                  companyName.isNotEmpty
                                      ? companyName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _cyan,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            )
                          : Text(
                              companyName.isNotEmpty
                                  ? companyName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _cyan,
                                fontSize: 18,
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            companyName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _pill(
                                mode == 'PDF' ? 'PDF Kit' : 'Interview Q&A',
                                mode == 'PDF' ? _purple : _cyan,
                              ),
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
                          isFavorite
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: isFavorite ? _amber : Colors.white38,
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
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Colors.white70,
                      height: 1.4,
                    ),
                  ),
                ],
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: tags.map((tag) => _tag(tag)).toList(),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      mode == 'PDF' ? 'Open PDF ↗' : 'Read Prep Guide →',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: _cyan,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _tag(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Text(
        tag,
        style: const TextStyle(fontSize: 11, color: Colors.white70),
      ),
    );
  }
}
