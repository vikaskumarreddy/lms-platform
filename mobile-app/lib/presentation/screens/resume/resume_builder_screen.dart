import 'package:flutter/material.dart';
import '../../../core/widgets/common_header.dart';

class ResumeBuilderScreen extends StatefulWidget {
  const ResumeBuilderScreen({super.key});
  @override
  State<ResumeBuilderScreen> createState() => _ResumeBuilderScreenState();
}

class _ResumeBuilderScreenState extends State<ResumeBuilderScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _githubController = TextEditingController();
  final _summaryController = TextEditingController();
  final List<String> _skills = [];
  final List<String> _certifications = [];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _linkedinController.dispose();
    _githubController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF0F172A);
    final secondaryColor = const Color(0xFFEAB308);

    return Scaffold(
      appBar: CommonHeader(
        title: 'Resume Builder',
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Resume PDF generated successfully')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.person, color: primaryColor),
                    const SizedBox(width: 12),
                    Text('Personal Information',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold, color: primaryColor)),
                  ]),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                        labelText: 'Full Name *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                        labelText: 'Email *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email_outlined)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                        labelText: 'Phone *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone_outlined)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _summaryController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                        labelText: 'Professional Summary',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.link, color: primaryColor),
                    const SizedBox(width: 12),
                    Text('Social Links',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold, color: primaryColor)),
                  ]),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _linkedinController,
                    decoration: const InputDecoration(
                        labelText: 'LinkedIn URL',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.link)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _githubController,
                    decoration: const InputDecoration(
                        labelText: 'GitHub URL',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.code)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Icon(Icons.lightbulb, color: primaryColor),
                        const SizedBox(width: 12),
                        Text('Skills',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold, color: primaryColor)),
                      ]),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _skills.add('New Skill ');
                          });
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _skills.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('No skills added yet',
                                style: TextStyle(color: Colors.grey)),
                          ),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _skills.asMap().entries.map((entry) {
                            return Chip(
                              label: Text(entry.value),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () =>
                                  setState(() => _skills.removeAt(entry.key)),
                              backgroundColor: secondaryColor.withOpacity(0.1),
                            );
                          }).toList(),
                        ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Icon(Icons.verified, color: primaryColor),
                        const SizedBox(width: 12),
                        Text('Certifications',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold, color: primaryColor)),
                      ]),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _certifications.add('New Certification ');
                          });
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _certifications.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('No certifications added yet',
                                style: TextStyle(color: Colors.grey)),
                          ),
                        )
                      : Column(
                          children: _certifications.asMap().entries.map((entry) {
                            return Card(
                              child: ListTile(
                                leading: const CircleAvatar(
                                    child: Icon(Icons.verified, color: Colors.green)),
                                title: Text(entry.value),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () => setState(
                                      () => _certifications.removeAt(entry.key)),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Resume generated successfully! ATS-ready PDF is ready.')),
                );
              },
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Generate ATS-Friendly Resume PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
