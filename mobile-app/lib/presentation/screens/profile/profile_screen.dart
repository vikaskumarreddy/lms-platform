import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/providers/data_providers.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/widgets/common_header.dart';
import '../../../../core/utils/avatar_utils.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isEditing = false;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _githubController = TextEditingController();

  bool _isSaving = false;

  static const _bgDark = Color(0xFF071D43);
  static const _cardDark = Color(0xFF0C2B64);
  static const _cyan = Color(0xFF27D9D3);
  static const _green = Color(0xFF10B981);

  Future<void> _toggleEditOrSave(BuildContext context) async {
    if (!_isEditing) {
      setState(() => _isEditing = true);
      return;
    }
    // Persist changes to backend
    setState(() => _isSaving = true);
    final success = await ref.read(apiServiceProvider).updateUserProfile(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          linkedin: _linkedinController.text.trim(),
          github: _githubController.text.trim(),
        );
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _isEditing = false;
    });
    ref.invalidate(userProfileProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? 'Profile updated successfully'
            : 'Failed to update profile. Please try again.'),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _linkedinController.dispose();
    _githubController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final coursesAsync = ref.watch(coursesProvider);
    final certsAsync = ref.watch(certificatesProvider);
    final isNavBarHidden = ref.watch(shellNavBarHiddenProvider);

    return CommonHeaderScaffold(
      subtitle: 'Profile',
      backgroundColor: _bgDark,
      body: profileAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: _cyan),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.white38),
              const SizedBox(height: 12),
              const Text('Failed to load profile',
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(userProfileProvider),
                child: const Text('Retry', style: TextStyle(color: _cyan)),
              ),
            ],
          ),
        ),
        data: (profile) {
          if (_nameController.text.isEmpty && profile != null) {
            _nameController.text = profile['name'] ?? '';
            _emailController.text = profile['email'] ?? '';
            _phoneController.text = profile['phone'] ?? '';
            _linkedinController.text = profile['linkedin'] ?? '';
            _githubController.text = profile['github'] ?? '';
          }

          final rawName = (profile?['name'] as String?)?.trim();
          final displayName =
              rawName == null || rawName.isEmpty ? 'Student' : rawName;
          final rawEmail = (profile?['email'] as String?)?.trim();
          final displayEmail =
              rawEmail == null || rawEmail.isEmpty ? 'No email' : rawEmail;
          final planName =
              profile?['planName'] ?? 'Java Placement Program';
          final batchName = profile?['batchName'] ?? 'Batch 0';

          final coursesCount = coursesAsync.valueOrNull?.length ?? 0;
          final certsCount = certsAsync.valueOrNull?.length ?? 0;

          // Profile completion calculation based on personal fields
          var profileFilled = 0;
          const profileTotal = 6;
          if (_nameController.text.trim().isNotEmpty) profileFilled++;
          if (_emailController.text.trim().isNotEmpty) profileFilled++;
          if (_phoneController.text.trim().isNotEmpty) profileFilled++;
          if (_linkedinController.text.trim().isNotEmpty) profileFilled++;
          if (_githubController.text.trim().isNotEmpty) profileFilled++;
          if (batchName.isNotEmpty && batchName != 'Not assigned') {
            profileFilled++;
          }
          final profileCompletion =
              ((profileFilled / profileTotal) * 100).round();

          // Resume completion percentage based on filled fields
          var resumeFilled = 0;
          const resumeTotal = 7;
          if (_nameController.text.trim().isNotEmpty) resumeFilled++;
          if (_emailController.text.trim().isNotEmpty) resumeFilled++;
          if (_phoneController.text.trim().isNotEmpty) resumeFilled++;
          if (_linkedinController.text.trim().isNotEmpty) resumeFilled++;
          if (_githubController.text.trim().isNotEmpty) resumeFilled++;
          if (certsCount > 0) resumeFilled++;
          if (coursesCount > 0) resumeFilled++;
          final resumeCompletion =
              ((resumeFilled / resumeTotal) * 100).round();

          return SafeArea(
            top: false,
            bottom: false,
            left: false,
            right: false,
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, 8, 16, isNavBarHidden ? 28 : 110),
              children: [
                // 1. Top Profile Card with Glowing Avatar & Upgrade Plan
                _buildTopProfileCard(
                  name: displayName,
                  email: displayEmail,
                ),
                const SizedBox(height: 16),

                // 2. 4 Stats Tiles Row: Profile Completion, Courses, Certificates, Resume %
                _buildStatsRow(
                  profilePercent: profileCompletion,
                  coursesCount: coursesCount,
                  certsCount: certsCount,
                  resumePercent: resumeCompletion,
                ),
                const SizedBox(height: 16),

                // 3. Personal Information Card (View/Edit)
                _buildPersonalInfoCard(context),
                const SizedBox(height: 16),

                // 4. Subscription Details Card
                _buildSubscriptionCard(
                  planName: planName,
                  batchName: batchName,
                ),
                const SizedBox(height: 16),

                // 5. Quick Actions 2x2 Grid (My Certificates, Resume Builder, Settings, Logout)
                _buildQuickActionsGrid(context),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 1. Top Profile Card with glowing avatar ring, name, email, and Upgrade button
  Widget _buildTopProfileCard({
    required String name,
    required String email,
  }) {
    final initials = AvatarUtils.initialsFor(name);

    return Container(
      decoration: BoxDecoration(
        color: _cardDark.withOpacity(0.75),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF1E5BB0).withOpacity(0.50)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              // Glowing Avatar with gradient outer ring
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF38BDF8), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF38BDF8).withOpacity(0.55),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(3.5),
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: const Color(0xFF092350),
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Name & Email
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF93C5FD),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Upgrade Plan Vibrant Pill Button
          Container(
            width: double.infinity,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: const LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFEAB308)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withOpacity(0.40),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.go(AppRoutes.subscription),
                borderRadius: BorderRadius.circular(26),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.arrow_upward_rounded,
                        color: Color(0xFF451A03), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Upgrade Plan',
                      style: TextStyle(
                        color: Color(0xFF451A03),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 2. 4 Stats Tiles Row: Profile Completion %, Courses Enrolled, Certificates, Resume %
  Widget _buildStatsRow({
    required int profilePercent,
    required int coursesCount,
    required int certsCount,
    required int resumePercent,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 24) / 4;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _statItem(
              width: cardWidth,
              icon: Icons.person_rounded,
              accent: const Color(0xFF38BDF8),
              value: '$profilePercent%',
              label: 'Profile Completion',
            ),
            _statItem(
              width: cardWidth,
              icon: Icons.menu_book_rounded,
              accent: const Color(0xFF2DD4BF),
              value: '$coursesCount',
              label: 'Courses Enrolled',
            ),
            _statItem(
              width: cardWidth,
              icon: Icons.workspace_premium_rounded,
              accent: const Color(0xFFA855F7),
              value: '$certsCount',
              label: 'Certificates',
            ),
            _statItem(
              width: cardWidth,
              icon: Icons.description_rounded,
              accent: const Color(0xFFFBBF24),
              value: '$resumePercent%',
              label: 'Resume Filling',
            ),
          ],
        );
      },
    );
  }

  Widget _statItem({
    required double width,
    required IconData icon,
    required Color accent,
    required String value,
    required String label,
  }) {
    return Container(
      width: width,
      height: 112,
      decoration: BoxDecoration(
        color: _cardDark.withOpacity(0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E5BB0).withOpacity(0.40)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Circular glowing icon container
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withOpacity(0.18),
              border: Border.all(color: accent.withOpacity(0.65), width: 1.2),
            ),
            child: Icon(icon, color: accent, size: 19),
          ),
          const SizedBox(height: 6),
          // Value
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          // Label
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  /// 3. Personal Information Card
  Widget _buildPersonalInfoCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cardDark.withOpacity(0.70),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E5BB0).withOpacity(0.45)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header with User Icon & Edit Pill Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withOpacity(0.25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_rounded,
                          color: Color(0xFF60A5FA), size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Personal Information',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _isSaving ? null : () => _toggleEditOrSave(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D4ED8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Row(
                          children: [
                            Icon(
                              _isEditing
                                  ? Icons.check_rounded
                                  : Icons.edit_rounded,
                              color: Colors.white,
                              size: 13,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _isEditing ? 'Save' : 'Edit',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_isEditing) ...[
            // Edit Mode: TextFields
            _editField('Full Name', _nameController, Icons.person_outline),
            const SizedBox(height: 10),
            _editField('Email', _emailController, Icons.email_outlined),
            const SizedBox(height: 10),
            _editField('Phone', _phoneController, Icons.phone_outlined),
            const SizedBox(height: 10),
            _editField('LinkedIn', _linkedinController, Icons.link_rounded),
            const SizedBox(height: 10),
            _editField('GitHub', _githubController, Icons.code_rounded),
          ] else ...[
            // View Mode: 3 columns (Phone, LinkedIn, GitHub)
            Row(
              children: [
                Expanded(
                  child: _infoColumn(
                    icon: Icons.phone_rounded,
                    iconBg: const Color(0xFF2563EB),
                    label: 'Phone',
                    value: _phoneController.text.isNotEmpty
                        ? _phoneController.text
                        : 'Not set',
                  ),
                ),
                Container(
                  width: 1,
                  height: 38,
                  color: Colors.white.withOpacity(0.12),
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),
                Expanded(
                  child: _infoColumn(
                    icon: Icons.work_outline_rounded,
                    iconBg: const Color(0xFF0D9488),
                    label: 'LinkedIn',
                    value: _linkedinController.text.isNotEmpty
                        ? _shortUrl(_linkedinController.text)
                        : 'Not set',
                  ),
                ),
                Container(
                  width: 1,
                  height: 38,
                  color: Colors.white.withOpacity(0.12),
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),
                Expanded(
                  child: _infoColumn(
                    icon: Icons.code_rounded,
                    iconBg: const Color(0xFF7C3AED),
                    label: 'GitHub',
                    value: _githubController.text.isNotEmpty
                        ? _shortUrl(_githubController.text)
                        : 'Not set',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoColumn({
    required IconData icon,
    required Color iconBg,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconBg,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.65),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _shortUrl(String url) {
    var clean = url.trim().replaceFirst(RegExp(r'^https?://(www\.)?'), '');
    if (clean.endsWith('/')) clean = clean.substring(0, clean.length - 1);
    return clean.isEmpty ? url : clean;
  }

  Widget _editField(
      String label, TextEditingController controller, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF104476).withOpacity(0.50),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: TextField(
        controller: controller,
        cursorColor: _cyan,
        style: const TextStyle(color: Colors.white, fontSize: 13.5),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.70)),
          prefixIcon: Icon(icon, color: _cyan, size: 18),
          filled: true,
          fillColor: Colors.transparent,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _cyan, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
      ),
    );
  }

  /// 4. Subscription Details Card
  Widget _buildSubscriptionCard({
    required String planName,
    required String batchName,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _cardDark.withOpacity(0.70),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E5BB0).withOpacity(0.45)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.card_giftcard_rounded,
                    color: Color(0xFF60A5FA), size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Subscription Details',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Plan Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Plan',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.65), fontSize: 13)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  planName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Batch Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Batch',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.65), fontSize: 13)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  batchName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Status Row with glowing green dot
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Status',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.65), fontSize: 13)),
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: _green,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _green.withOpacity(0.7),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Active',
                    style: TextStyle(
                      color: _green,
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Full-width Payment History Button
          Container(
            width: double.infinity,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.go(AppRoutes.paymentHistory),
                borderRadius: BorderRadius.circular(22),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.payment_rounded,
                          color: Colors.white, size: 18),
                      SizedBox(width: 10),
                      Text(
                        'Payment History',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Spacer(),
                      Icon(Icons.chevron_right_rounded,
                          color: Colors.white70, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 5. Quick Actions 2x2 Grid (My Certificates, Resume Builder, Settings, Logout)
  Widget _buildQuickActionsGrid(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _actionCard(
                icon: Icons.workspace_premium_rounded,
                iconColor: const Color(0xFFA855F7),
                title: 'My Certificates',
                subtitle: 'View achievements',
                onTap: () => context.go(AppRoutes.certificates),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _actionCard(
                icon: Icons.description_rounded,
                iconColor: const Color(0xFF14B8A6),
                title: 'Resume Builder',
                subtitle: 'Create your resume',
                onTap: () => context.go(AppRoutes.resumeBuilder),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _actionCard(
                icon: Icons.settings_rounded,
                iconColor: const Color(0xFFF59E0B),
                title: 'Settings',
                subtitle: 'Manage your account',
                onTap: () => context.go(AppRoutes.settings),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              // Explicit user requirement: "instead of more menu add logout option"
              child: _actionCard(
                icon: Icons.logout_rounded,
                iconColor: const Color(0xFF38BDF8),
                title: 'Logout',
                subtitle: 'Sign out',
                onTap: () async {
                  await ref.read(mobileAuthProvider.notifier).logout();
                  if (!context.mounted) return;
                  context.go(AppRoutes.login);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: _cardDark.withOpacity(0.70),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1E5BB0).withOpacity(0.40)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Circular icon badge
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 10),
                // Title & Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.60),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withOpacity(0.40),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
