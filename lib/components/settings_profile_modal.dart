import 'dart:ui';
import 'package:codemate/auth/auth_gate.dart';
import 'package:codemate/providers/auth_provider.dart';
import 'package:codemate/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';

import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

class SettingsProfileModal extends ConsumerStatefulWidget {
  const SettingsProfileModal({super.key});

  @override
  ConsumerState<SettingsProfileModal> createState() =>
      _SettingsProfileModalState();
}

class _SettingsProfileModalState extends ConsumerState<SettingsProfileModal> {
  int _selectedIndex = 0; // 0 for Settings, 1 for Profile

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: 500,
            height: 350,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: Row(
                children: [
                  _buildTabs(),
                  Expanded(
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: [
                        _buildSettingsContent(),
                        _buildProfileContent(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.white.withOpacity(0.2))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTabItem(Icons.settings_outlined, 'Settings', 0),
          const SizedBox(height: 16),
          _buildTabItem(Icons.person_outline, 'Profile', 1),
        ],
      ),
    );
  }

  Widget _buildTabItem(IconData icon, String title, int index) {
    final bool isSelected = _selectedIndex == index;
    return Material(
      color:
          isSelected ? Colors.blueAccent.withOpacity(0.3) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsContent() {
    final settings = ref.watch(userSettingsProvider);
    final settingsNotifier = ref.read(userSettingsProvider.notifier);

    return settings.when(
      data: (data) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.white),
            ),
            const SizedBox(height: 24),
            // Theme Toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Theme',
                    style:
                        GoogleFonts.poppins(fontSize: 16, color: Colors.white70)),
                Switch(
                  value: data.theme == 'dark',
                  onChanged: (val) {
                    settingsNotifier.updateTheme(val ? 'dark' : 'light');
                  },
                  activeColor: Colors.blueAccent,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Notifications Toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Notifications',
                    style:
                        GoogleFonts.poppins(fontSize: 16, color: Colors.white70)),
                Switch(
                  value: data.notificationsEnabled,
                  onChanged: (val) {
                    settingsNotifier.updateNotifications(val);
                  },
                  activeColor: Colors.blueAccent,
                ),
              ],
            ),
            const Spacer(),
            // Logout and Delete Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    await ref.read(authServiceProvider).logout();
                    if (mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => const AuthGate()),
                        (route) => false,
                      );
                    }
                  },
                  icon: const Icon(Icons.logout_rounded, color: Colors.white70),
                  label: Text(
                    'Sign Out',
                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16),
                  ),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final shouldDelete = await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Account?'),
                        content: const Text('This action is irreversible. Are you sure you want to delete your account?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Delete', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );

                    if (shouldDelete == true) {
                      try {
                        await ref.read(authServiceProvider).deleteAccount();
                        if (mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (context) => const AuthGate()),
                            (route) => false,
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to delete account: $e')),
                          );
                        }
                      }
                    }
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  label: Text(
                    'Delete Account',
                    style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 16),
                  ),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildProfileContent() {
    final authUser = ref.watch(authUserProvider);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Profile',
            style: GoogleFonts.poppins(
                fontSize: 24, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const SizedBox(height: 24),
          authUser.when(
            data: (user) {
              if (user == null) {
                return const Center(child: Text('Not logged in'));
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: NetworkImage(user.userMetadata?['avatar_url'] ?? ''),
                        child: user.userMetadata?['avatar_url'] == null
                            ? const Icon(Icons.person, size: 50)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: IconButton(
                          icon: const Icon(Icons.edit, color: Colors.white),
                          onPressed: () async {
                            final picker = ImagePicker();
                            final pickedFile = await picker.pickImage(source: ImageSource.gallery);

                            if (pickedFile != null) {
                              final file = File(pickedFile.path);
                              try {
                                await ref.read(authServiceProvider).uploadAvatar(file);
                                // Refresh the user to get the new avatar_url
                                ref.refresh(authUserProvider);
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to upload avatar: $e')),
                                  );
                                }
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ListTile(
                    leading: const Icon(Icons.email_outlined, color: Colors.white70),
                    title: Text('Email', style: GoogleFonts.poppins(color: Colors.white70)),
                    subtitle: Text(user.email ?? 'No email associated',
                        style: GoogleFonts.poppins(color: Colors.white)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.person_outline, color: Colors.white70),
                    title: Text('Name', style: GoogleFonts.poppins(color: Colors.white70)),
                    subtitle: Text(user.userMetadata?['full_name'] ?? 'No name set',
                        style: GoogleFonts.poppins(color: Colors.white)),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          )
        ],
      ),
    );
  }
}
