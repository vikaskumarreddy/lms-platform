import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/widgets/common_header.dart';

/// Lets a student ask placements staff a question about a specific drive, or
/// about a company that isn't listed ("Other" + free-text name). An org admin
/// answers once from the Placements page's Support tab; the reply shows up
/// below in this student's own request history.
class SupportRequestScreen extends ConsumerStatefulWidget {
  const SupportRequestScreen({super.key});

  @override
  ConsumerState<SupportRequestScreen> createState() => _SupportRequestScreenState();
}

class _SupportRequestScreenState extends ConsumerState<SupportRequestScreen> {
  static const _otherValue = -1;

  int? _selectedDriveId;
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  bool _submitting = false;
  List<Map<String, dynamic>> _myRequests = [];
  bool _loadingRequests = true;

  @override
  void initState() {
    super.initState();
    _loadMyRequests();
  }

  @override
  void dispose() {
    _companyController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadMyRequests() async {
    final requests = await ref.read(apiServiceProvider).getMySupportRequests();
    if (!mounted) return;
    setState(() {
      _myRequests = requests;
      _loadingRequests = false;
    });
  }

  Future<void> _handleSubmit() async {
    final isOther = _selectedDriveId == null || _selectedDriveId == _otherValue;
    if (_selectedDriveId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a drive or "Other"')),
      );
      return;
    }
    if (isOther && _companyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the company name')),
      );
      return;
    }
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe your question')),
      );
      return;
    }

    setState(() => _submitting = true);
    final error = await ref.read(apiServiceProvider).submitSupportRequest(
          driveId: isOther ? null : _selectedDriveId,
          companyName: isOther ? _companyController.text.trim() : null,
          message: _messageController.text.trim(),
        );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your request has been sent to placements.')),
      );
      _messageController.clear();
      _companyController.clear();
      setState(() => _selectedDriveId = null);
      _loadMyRequests();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF0F172A);
    final secondaryColor = const Color(0xFFEAB308);
    final drivesAsync = ref.watch(placementDrivesProvider);

    return Scaffold(
      appBar: const CommonHeader(title: 'Request Support', showBackButton: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ask about a drive', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: primaryColor)),
                    const SizedBox(height: 16),
                    const Text('Company / Drive', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    drivesAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Could not load drives', style: TextStyle(color: Colors.red.shade400)),
                      data: (drives) => DropdownButtonFormField<int>(
                        value: _selectedDriveId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        hint: const Text('Select a drive'),
                        items: [
                          ...drives.map((d) => DropdownMenuItem(value: d.id, child: Text(d.companyName))),
                          const DropdownMenuItem(value: _otherValue, child: Text('Other (not listed)')),
                        ],
                        onChanged: (value) => setState(() => _selectedDriveId = value),
                      ),
                    ),
                    if (_selectedDriveId == _otherValue) ...[
                      const SizedBox(height: 16),
                      const Text('Company name', style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _companyController,
                        decoration: InputDecoration(
                          hintText: 'e.g. Acme Corp',
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Text('Your question', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _messageController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'What would you like to ask?',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                        child: _submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Submit Request'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Your Requests', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: primaryColor)),
            const SizedBox(height: 12),
            if (_loadingRequests)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_myRequests.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'You haven\'t asked anything yet.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _myRequests.length,
                itemBuilder: (context, index) {
                  final item = _myRequests[index];
                  final status = (item['status'] as String?) ?? 'PENDING';
                  final isResponded = status == 'RESPONDED';
                  final companyName = (item['companyName'] as String?) ?? '';
                  final message = (item['message'] as String?) ?? '';
                  final adminResponse = item['adminResponse'] as String?;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(companyName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (isResponded ? Colors.green : secondaryColor).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isResponded ? 'Responded' : 'Pending',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isResponded ? Colors.green.shade700 : const Color(0xFFB45309),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(message, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                          if (adminResponse != null && adminResponse.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border(left: BorderSide(color: primaryColor, width: 3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Response', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                                  const SizedBox(height: 4),
                                  Text(adminResponse, style: const TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
