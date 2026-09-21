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
  ConsumerState<SupportRequestScreen> createState() =>
      _SupportRequestScreenState();
}

class _SupportRequestScreenState extends ConsumerState<SupportRequestScreen> {
  static const _otherValue = -1;

  static const _bgDark = Color(0xFF071D43);
  static const _cardDark = Color(0xFF0C2B64);
  static const _cyan = Color(0xFF27D9D3);
  static const _green = Color(0xFF10B981);
  static const _amber = Color(0xFFF59E0B);

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
    final isOther =
        _selectedDriveId == null || _selectedDriveId == _otherValue;
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
        const SnackBar(
          content: Text('Your request has been sent to placements.'),
          backgroundColor: _green,
        ),
      );
      _messageController.clear();
      _companyController.clear();
      setState(() => _selectedDriveId = null);
      _loadMyRequests();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final drivesAsync = ref.watch(placementDrivesProvider);

    return CommonHeaderScaffold(
      subtitle: 'Support',
      showBackButton: true,
      backgroundColor: _bgDark,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 130),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Support Form Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _cardDark.withOpacity(0.70),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                    color: const Color(0xFF1E5BB0).withOpacity(0.45)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _cyan.withOpacity(0.20),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.support_agent_rounded,
                            color: _cyan, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ask Placement Staff',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Get assistance regarding drives and interviews',
                              style: TextStyle(
                                  color: Colors.white60, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Select Company / Drive',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  drivesAsync.when(
                    loading: () => const LinearProgressIndicator(color: _cyan),
                    error: (e, _) => const Text(
                      'Could not load drives',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                    data: (drives) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF104476).withOpacity(0.55),
                        borderRadius: BorderRadius.circular(14),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.15)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _selectedDriveId,
                          isExpanded: true,
                          menuMaxHeight: 260,
                          dropdownColor: const Color(0xFF092350),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded,
                              color: _cyan),
                          hint: const Text(
                            'Choose a drive or "Other"',
                            style:
                                TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                          items: [
                            ...drives.map((d) => DropdownMenuItem(
                                  value: d.id,
                                  child: Text(
                                    d.companyName,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 13.5),
                                  ),
                                )),
                            const DropdownMenuItem(
                              value: _otherValue,
                              child: Text(
                                'Other (Not listed)',
                                style: TextStyle(
                                    color: _cyan,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                          onChanged: (val) =>
                              setState(() => _selectedDriveId = val),
                        ),
                      ),
                    ),
                  ),
                  if (_selectedDriveId == _otherValue) ...[
                    const SizedBox(height: 14),
                    const Text(
                      'Company Name',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF104476).withOpacity(0.55),
                        borderRadius: BorderRadius.circular(14),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.15)),
                      ),
                      child: TextField(
                        controller: _companyController,
                        cursorColor: _cyan,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13.5),
                        decoration: const InputDecoration(
                          filled: true,
                          fillColor: Colors.transparent,
                          hintText: 'e.g. Google, Amazon, Infosys...',
                          hintStyle:
                              TextStyle(color: Colors.white54, fontSize: 13),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  const Text(
                    'Your Question or Issue',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF104476).withOpacity(0.55),
                      borderRadius: BorderRadius.circular(14),
                      border:
                          Border.all(color: Colors.white.withOpacity(0.15)),
                    ),
                    child: TextField(
                      controller: _messageController,
                      cursorColor: _cyan,
                      maxLines: 4,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 13.5),
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Colors.transparent,
                        hintText:
                            'Describe your query regarding this drive, eligibility, or process in detail...',
                        hintStyle:
                            TextStyle(color: Colors.white54, fontSize: 13),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.all(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _cyan,
                        foregroundColor: const Color(0xFF041838),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF041838),
                              ),
                            )
                          : const Text(
                              'Submit Support Request',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 2. Your Requests History
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 10),
              child: Text(
                'Your Request History',
                style: TextStyle(
                  color: Color(0xFF93C5FD),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            if (_loadingRequests)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                    child: CircularProgressIndicator(color: _cyan)),
              )
            else if (_myRequests.isEmpty)
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: _cardDark.withOpacity(0.50),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFF1E5BB0).withOpacity(0.35)),
                ),
                child: const Center(
                  child: Column(
                    children: [
                      Icon(Icons.inbox_rounded,
                          size: 44, color: Colors.white30),
                      SizedBox(height: 10),
                      Text(
                        'You haven\'t submitted any requests yet.',
                        style: TextStyle(color: Colors.white70, fontSize: 13.5),
                      ),
                    ],
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
                  final companyName =
                      (item['companyName'] as String?) ?? 'General Request';
                  final message = (item['message'] as String?) ?? '';
                  final adminResponse = item['adminResponse'] as String?;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _cardDark.withOpacity(0.70),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFF1E5BB0).withOpacity(0.45)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.20),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                companyName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isResponded
                                    ? _green.withOpacity(0.20)
                                    : _amber.withOpacity(0.20),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isResponded
                                      ? _green.withOpacity(0.45)
                                      : _amber.withOpacity(0.45),
                                ),
                              ),
                              child: Text(
                                isResponded ? 'Responded' : 'Pending',
                                style: TextStyle(
                                  color: isResponded ? _green : _amber,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          message,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white70,
                            height: 1.4,
                          ),
                        ),
                        if (adminResponse != null &&
                            adminResponse.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F386B).withOpacity(0.60),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: _cyan.withOpacity(0.35)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.admin_panel_settings_rounded,
                                        size: 16, color: _cyan),
                                    SizedBox(width: 6),
                                    Text(
                                      'Staff Response',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: _cyan,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  adminResponse,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.white,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
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
