import 'package:flutter/material.dart';
import '../../../core/widgets/common_header.dart';

class CertificatesScreen extends StatefulWidget {
  const CertificatesScreen({super.key});

  @override
  State<CertificatesScreen> createState() => _CertificatesScreenState();
}

class _CertificatesScreenState extends State<CertificatesScreen> {
  String _selectedFilter = 'All';
  final List<_CertificateItem> _certificates = [
    _CertificateItem(
      id: 1,
      title: 'Java Programming',
      issueDate: '15 Dec 2025',
      expiryDate: '15 Dec 2027',
      status: 'Active',
      credentialId: 'CERT-JAVA-2025-001',
    ),
    _CertificateItem(
      id: 2,
      title: 'Data Structures',
      issueDate: '10 Nov 2025',
      expiryDate: '10 Nov 2027',
      status: 'Active',
      credentialId: 'CERT-DS-2025-002',
    ),
    _CertificateItem(
      id: 3,
      title: 'Web Development',
      issueDate: '05 Oct 2025',
      expiryDate: '05 Oct 2027',
      status: 'Active',
      credentialId: 'CERT-WEB-2025-003',
    ),
    _CertificateItem(
      id: 4,
      title: 'Python Basics',
      issueDate: '20 Sep 2025',
      expiryDate: '20 Sep 2026',
      status: 'Expiring Soon',
      credentialId: 'CERT-PY-2025-004',
    ),
  ];

  List<_CertificateItem> get _filteredCertificates {
    if (_selectedFilter == 'All') return _certificates;
    return _certificates.where((c) => c.status == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF0F172A);
    final secondaryColor = const Color(0xFFEAB308);

    return Scaffold(
      appBar: const CommonHeader(title: 'Certificates'),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.grey.shade50),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search certificates...',
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
              children: ['All', 'Active', 'Expiring Soon'].map((filter) {
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
            child: _filteredCertificates.isEmpty
                ? Center(child: Text('No certificates found', style: TextStyle(color: Colors.grey.shade500)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredCertificates.length,
                    itemBuilder: (context, index) {
                      final cert = _filteredCertificates[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: secondaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(Icons.workspace_premium, color: secondaryColor, size: 32),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(cert.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        const SizedBox(height: 4),
                                        Text('Issued: ${cert.issueDate}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: cert.status == 'Active' ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(cert.status, style: TextStyle(fontSize: 11, color: cert.status == 'Active' ? Colors.green : Colors.orange, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Credential ID', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                      const SizedBox(height: 2),
                                      Text(cert.credentialId, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('Expires', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                      const SizedBox(height: 2),
                                      Text(cert.expiryDate, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {},
                                      icon: const Icon(Icons.visibility, size: 18),
                                      label: const Text('View'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {},
                                      icon: const Icon(Icons.download, size: 18),
                                      label: const Text('Download'),
                                      style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                                    ),
                                  ),
                                ],
                              ),
                            ],
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

class _CertificateItem {
  final int id;
  final String title;
  final String issueDate;
  final String expiryDate;
  final String status;
  final String credentialId;

  _CertificateItem({
    required this.id,
    required this.title,
    required this.issueDate,
    required this.expiryDate,
    required this.status,
    required this.credentialId,
  });
}