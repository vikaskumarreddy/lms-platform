import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/routes.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/widgets/common_header.dart';
import '../../../data/models/bookmark_model.dart';

class BookmarksScreen extends ConsumerStatefulWidget {
  const BookmarksScreen({super.key});

  @override
  ConsumerState<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends ConsumerState<BookmarksScreen> {
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF0F172A);
    final secondaryColor = const Color(0xFFEAB308);
    final bookmarksAsync = ref.watch(bookmarksProvider);

    return Scaffold(
      appBar: const CommonHeader(title: 'Bookmarks'),
      body: bookmarksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text('Failed to load bookmarks', style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(bookmarksProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (bookmarks) {
          final filtered = _selectedFilter == 'All'
              ? bookmarks
              : bookmarks.where((b) => b.lessonType == _selectedFilter).toList();

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.grey.shade50),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search bookmarks...',
                          prefixIcon: const Icon(Icons.search, size: 20),
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
                  children: ['All', 'Lesson', 'Module Lesson'].map((filter) {
                    final isSelected = _selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(filter),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _selectedFilter = filter),
                        selectedColor: secondaryColor,
                        backgroundColor: Colors.grey.shade100,
                        labelStyle: TextStyle(color: isSelected ? Colors.black : Colors.grey.shade700),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(child: Text('No bookmarks found', style: TextStyle(color: Colors.grey.shade500)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final bookmark = filtered[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: bookmark.lessonType == 'Lesson' ? Colors.blue.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                                child: Icon(bookmark.lessonType == 'Lesson' ? Icons.play_circle : Icons.menu_book, color: bookmark.lessonType == 'Lesson' ? Colors.blue : Colors.green),
                              ),
                              title: Text(bookmark.lessonTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(bookmark.bookmarkedAt, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                  if (bookmark.courseName != null) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(bookmark.courseName!, style: TextStyle(fontSize: 10, color: Colors.purple, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ],
                              ),
                              trailing: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () async {
                                  final api = ref.read(apiServiceProvider);
                                  final success = await api.deleteBookmark(bookmark.lessonId);
                                  if (success && mounted) {
                                    ref.invalidate(bookmarksProvider);
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bookmark removed')));
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                                  child: Icon(Icons.delete_rounded, color: Colors.red.shade400, size: 20),
                                ),
                              ),
                              onTap: () {
                                context.go(AppRoutes.lesson.replaceAll(':lessonId', '${bookmark.lessonId}'));
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}