import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/routes.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/widgets/common_header.dart';

class BookmarksScreen extends ConsumerStatefulWidget {
  const BookmarksScreen({super.key});

  @override
  ConsumerState<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends ConsumerState<BookmarksScreen> {
  String _selectedFilter = 'All';
  String _search = '';

  static const _bgDark = Color(0xFF071D43);
  static const _cardDark = Color(0xFF0C2B64);
  static const _cyan = Color(0xFF27D9D3);
  static const _purple = Color(0xFF9B5CFF);

  @override
  Widget build(BuildContext context) {
    final bookmarksAsync = ref.watch(bookmarksProvider);

    return CommonHeaderScaffold(
      subtitle: 'Bookmarks',
      backgroundColor: _bgDark,
      body: bookmarksAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _cyan)),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: Colors.white38),
              const SizedBox(height: 12),
              const Text('Failed to load bookmarks',
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(bookmarksProvider),
                child: const Text('Retry', style: TextStyle(color: _cyan)),
              ),
            ],
          ),
        ),
        data: (bookmarks) {
          final filtered = bookmarks.where((b) {
            if (_selectedFilter != 'All' &&
                b.lessonType != _selectedFilter) {
              return false;
            }
            if (_search.trim().isNotEmpty) {
              final q = _search.trim().toLowerCase();
              final title = b.lessonTitle.toLowerCase();
              final course = (b.courseName ?? '').toLowerCase();
              return title.contains(q) || course.contains(q);
            }
            return true;
          }).toList();

          return Column(
            children: [
              // Search Container
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _cardDark.withOpacity(0.70),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: const Color(0xFF1E5BB0).withOpacity(0.45)),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF104476).withOpacity(0.55),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    cursorColor: _cyan,
                    style:
                        const TextStyle(color: Colors.white, fontSize: 13.5),
                    decoration: const InputDecoration(
                      hintText: 'Search bookmarked lessons...',
                      hintStyle:
                          TextStyle(color: Colors.white54, fontSize: 13),
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
              ),

              // Filter chips
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: ['All', 'Lesson', 'Module Lesson'].map((filter) {
                    final isSelected = _selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () => setState(() => _selectedFilter = filter),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF104476)
                                : Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? _cyan
                                  : Colors.white.withOpacity(0.12),
                            ),
                          ),
                          child: Text(
                            filter,
                            style: TextStyle(
                              color: isSelected ? _cyan : Colors.white70,
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 6),

              // Bookmark list
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.bookmark_border_rounded,
                                size: 56, color: Colors.white24),
                            const SizedBox(height: 12),
                            const Text('No bookmarks found',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 15)),
                            const SizedBox(height: 4),
                            const Text(
                              'Tap the bookmark icon in any lesson to save it here',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 90),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final bookmark = filtered[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: _cardDark.withOpacity(0.70),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color:
                                    const Color(0xFF1E5BB0).withOpacity(0.45),
                              ),
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
                                onTap: () {
                                  context.go(AppRoutes.lesson.replaceAll(
                                      ':lessonId', '${bookmark.lessonId}'));
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: (bookmark.lessonType ==
                                                      'Lesson'
                                                  ? _cyan
                                                  : _purple)
                                              .withOpacity(0.20),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          bookmark.lessonType == 'Lesson'
                                              ? Icons
                                                  .play_circle_fill_rounded
                                              : Icons.menu_book_rounded,
                                          color: bookmark.lessonType ==
                                                  'Lesson'
                                              ? _cyan
                                              : _purple,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              bookmark.lessonTitle,
                                              maxLines: 2,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14.5,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                if (bookmark.courseName !=
                                                    null) ...[
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8,
                                                        vertical: 2),
                                                    decoration:
                                                        BoxDecoration(
                                                      color: _purple
                                                          .withOpacity(0.20),
                                                      borderRadius:
                                                          BorderRadius
                                                              .circular(6),
                                                    ),
                                                    child: Text(
                                                      bookmark.courseName!,
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        color: Color(
                                                            0xFFC084FC),
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                ],
                                                Text(
                                                  bookmark.bookmarkedAt,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.white54,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                            Icons.bookmark_remove_rounded,
                                            color: Color(0xFFF87171),
                                            size: 22),
                                        tooltip: 'Remove bookmark',
                                        onPressed: () async {
                                          final api =
                                              ref.read(apiServiceProvider);
                                          final success =
                                              await api.deleteBookmark(
                                                  bookmark.lessonId);
                                          if (success && mounted) {
                                            ref.invalidate(
                                                bookmarksProvider);
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    'Bookmark removed'),
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
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
