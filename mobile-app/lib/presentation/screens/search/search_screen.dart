import 'package:flutter/material.dart';
import '../../../core/widgets/common_header.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  final List<_SearchResult> _results = [
    _SearchResult(type: 'Course', title: 'Java Programming', description: 'Complete Java course for beginners', icon: Icons.book),
    _SearchResult(type: 'Lesson', title: 'Introduction to Streams', description: 'Learn Java Streams API', icon: Icons.play_circle),
    _SearchResult(type: 'Quiz', title: 'Java Fundamentals Quiz', description: 'Test your Java knowledge', icon: Icons.quiz),
    _SearchResult(type: 'Assignment', title: 'OOP Concepts Assignment', description: 'Submit your assignment', icon: Icons.assignment),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonHeader(title: 'Search'),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.grey.shade50),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search courses, lessons, quizzes...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty ? IconButton(onPressed: () => _searchController.clear(), icon: const Icon(Icons.clear)) : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: ['All', 'Course', 'Lesson', 'Quiz', 'Assignment'].map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedFilter = filter),
                    selectedColor: Theme.of(context).colorScheme.secondary,
                    backgroundColor: Colors.grey.shade100,
                    labelStyle: TextStyle(color: isSelected ? Colors.black : Colors.grey.shade700),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: _searchController.text.isEmpty && _selectedFilter == 'All'
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('Search for courses, lessons, and more', style: TextStyle(color: Colors.grey.shade500)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _results.where((r) => _selectedFilter == 'All' || r.type == _selectedFilter).length,
                    itemBuilder: (context, index) {
                      final result = _results.where((r) => _selectedFilter == 'All' || r.type == _selectedFilter).toList()[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.withOpacity(0.1),
                            child: Icon(result.icon, color: Colors.blue),
                          ),
                          title: Text(result.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(result.description),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(result.type, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SearchResult {
  final String type;
  final String title;
  final String description;
  final IconData icon;
  _SearchResult({required this.type, required this.title, required this.description, required this.icon});
}