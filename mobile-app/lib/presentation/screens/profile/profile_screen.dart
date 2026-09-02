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

  Future<void> _toggleEditOrSave(BuildContext context) async {
    if (!_isEditing) {
      setState(() => _isEditing = true);
      return;
    }
    // Currently editing -> persist changes to backend.
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
      SnackBar(content: Text(success ? 'Profile updated successfully' : 'Failed to update profile. Please try again.')),
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
    final primaryColor = const Color(0xFF0F172A);
    final secondaryColor = const Color(0xFFEAB308);
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: CommonHeader(
        title: 'Profile',
        actions: [
          IconButton(icon: Icon(_isEditing ? Icons.check : Icons.edit_outlined), onPressed: () => _toggleEditOrSave(context)),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text('Failed to load profile', style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(userProfileProvider),
                child: const Text('Retry'),
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
          final planName = profile?['planName'] ?? 'Free';
          final batchName = profile?['batchName'] ?? 'Not assigned';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: const Color(0xFF0F172A),
                  child: Text(
                    AvatarUtils.initialsFor(profile?['name'] ?? _nameController.text),
                    style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                if (_isEditing)
                  TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()))
                else
                  Text(_nameController.text, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                if (_isEditing)
                  TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()))
                else
                  Text(_emailController.text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () => context.go(AppRoutes.subscription), icon: const Icon(Icons.upgrade, size: 20), label: const Text('Upgrade Plan'), style: ElevatedButton.styleFrom(backgroundColor: secondaryColor, foregroundColor: primaryColor))),
              ]))),
              const SizedBox(height: 20),
              Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Personal Information', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: primaryColor)),
                  TextButton.icon(onPressed: _isSaving ? null : () => _toggleEditOrSave(context), icon: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(_isEditing ? Icons.check : Icons.edit, size: 18), label: Text(_isEditing ? 'Save' : 'Edit')),
                ]),
                const SizedBox(height: 12),
                if (_isEditing) ...[
                  TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone))),
                  const SizedBox(height: 12),
                  TextField(controller: _linkedinController, decoration: const InputDecoration(labelText: 'LinkedIn', border: OutlineInputBorder(), prefixIcon: Icon(Icons.link))),
                  const SizedBox(height: 12),
                  TextField(controller: _githubController, decoration: const InputDecoration(labelText: 'GitHub', border: OutlineInputBorder(), prefixIcon: Icon(Icons.link))),
                ] else ...[
                  ListTile(leading: const Icon(Icons.phone), title: const Text('Phone'), subtitle: Text(_phoneController.text)),
                  ListTile(leading: const Icon(Icons.link), title: const Text('LinkedIn'), subtitle: Text(_linkedinController.text)),
                  ListTile(leading: const Icon(Icons.link), title: const Text('GitHub'), subtitle: Text(_githubController.text)),
                ],
              ]))),
              const SizedBox(height: 20),
              Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Subscription Details', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: primaryColor)),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Plan'), Text(planName)]),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Batch'), Text(batchName, style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600))]),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Status'), Text('Active', style: TextStyle(color: secondaryColor, fontWeight: FontWeight.bold))]),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => context.go(AppRoutes.paymentHistory), icon: const Icon(Icons.payment, size: 18), label: const Text('Payment History'))),
              ]))),
              const SizedBox(height: 20),
              ListTile(leading: const Icon(Icons.emoji_events_outlined), title: const Text('My Certificates'), subtitle: const Text('View achievements'), trailing: const Icon(Icons.chevron_right), onTap: () => context.go(AppRoutes.certificates)),
              ListTile(leading: const Icon(Icons.description_outlined), title: const Text('Resume Builder'), subtitle: const Text('Create your resume'), trailing: const Icon(Icons.chevron_right), onTap: () => context.go(AppRoutes.resumeBuilder)),
              ListTile(leading: const Icon(Icons.settings_outlined), title: const Text('Settings'), subtitle: const Text('App preferences'), trailing: const Icon(Icons.chevron_right), onTap: () => context.go(AppRoutes.settings)),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                subtitle: const Text('Sign out'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  // Clear the persisted session (token + cached user) before
                  // navigating, otherwise the next app launch auto-logs-in.
                  await ref.read(mobileAuthProvider.notifier).logout();
                  if (!mounted) return;
                  context.go(AppRoutes.login);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}