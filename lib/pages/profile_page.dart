import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:careslot/core/theme/app_theme.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      if (!mounted) return;
      setState(() => _profile = data);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profile: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await _supabase.auth.signOut();
    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
              ? const Center(child: Text('Profile not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // 1. Header (Avatar, Name, Role)
                      const SizedBox(height: 16),
                      Center(
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: AppColors.primaryTint,
                          backgroundImage: _profile!['avatar_url'] != null
                              ? NetworkImage(_profile!['avatar_url'])
                              : null,
                          child: _profile!['avatar_url'] == null
                              ? const Icon(Icons.person,
                                  size: 50, color: AppColors.primary)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _profile!['full_name'] ?? 'User',
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _supabase.auth.currentUser?.email ?? '',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryTint,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          (_profile!['role'] as String? ?? 'patient')
                              .toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // 2. Account Settings Group
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Account',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        margin: EdgeInsets.zero,
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.phone_outlined,
                                  color: AppColors.primary),
                              title: const Text('Phone Number'),
                              subtitle: Text(
                                _profile!['phone'] ?? 'Not provided',
                                style: const TextStyle(color: AppColors.textSecondary),
                              ),
                              trailing: const Icon(Icons.chevron_right,
                                  color: Colors.grey),
                              onTap: () {
                                // TODO: Implement edit phone
                              },
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.payment_outlined,
                                  color: AppColors.primary),
                              title: const Text('Payment Methods'),
                              trailing: const Icon(Icons.chevron_right,
                                  color: Colors.grey),
                              onTap: () {
                                // TODO: Implement payment methods screen
                              },
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),

                      // 3. Support Group
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Support',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        margin: EdgeInsets.zero,
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.help_outline,
                                  color: AppColors.primary),
                              title: const Text('Help Center'),
                              trailing: const Icon(Icons.chevron_right,
                                  color: Colors.grey),
                              onTap: () {},
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.privacy_tip_outlined,
                                  color: AppColors.primary),
                              title: const Text('Privacy Policy'),
                              trailing: const Icon(Icons.chevron_right,
                                  color: Colors.grey),
                              onTap: () {},
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 48),

                      // 4. Logout Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout, color: Colors.red),
                          label: const Text(
                            'Log Out',
                            style: TextStyle(color: Colors.red),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}