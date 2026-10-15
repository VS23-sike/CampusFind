import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../services/api_service.dart';
import '../widgets/common.dart';
import 'help.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool notifications = true;
  bool aiMatches = true;
  bool messages = true;
  bool claimUpdates = true;
  bool locationServices = true;

  Future<void> changePassword() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.email == null) {
      showError(
        context,
        'Unable to identify your account.',
      );
      return;
    }

    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    bool saving = false;
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Change Password'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: currentController,
                      obscureText: obscureCurrent,
                      decoration: InputDecoration(
                        labelText: 'Current password',
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                        ),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setDialogState(() {
                              obscureCurrent = !obscureCurrent;
                            });
                          },
                          icon: Icon(
                            obscureCurrent
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newController,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: 'New password',
                        prefixIcon: const Icon(
                          Icons.lock_reset_outlined,
                        ),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setDialogState(() {
                              obscureNew = !obscureNew;
                            });
                          },
                          icon: Icon(
                            obscureNew
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmController,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirm new password',
                        prefixIcon: const Icon(
                          Icons.verified_user_outlined,
                        ),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setDialogState(() {
                              obscureConfirm = !obscureConfirm;
                            });
                          },
                          icon: Icon(
                            obscureConfirm
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Use at least 8 characters for your new password.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final current = currentController.text;
                          final newPassword = newController.text;
                          final confirm = confirmController.text;

                          if (current.isEmpty ||
                              newPassword.isEmpty ||
                              confirm.isEmpty) {
                            showError(
                              context,
                              'Please fill in all password fields.',
                            );
                            return;
                          }

                          if (newPassword.length < 8) {
                            showError(
                              context,
                              'New password must contain at least 8 characters.',
                            );
                            return;
                          }

                          if (newPassword != confirm) {
                            showError(
                              context,
                              'New passwords do not match.',
                            );
                            return;
                          }

                          setDialogState(() {
                            saving = true;
                          });

                          try {
                            final credential = EmailAuthProvider.credential(
                              email: user.email!,
                              password: current,
                            );

                            await user.reauthenticateWithCredential(
                              credential,
                            );

                            await user.updatePassword(
                              newPassword,
                            );

                            if (!mounted) return;

                            Navigator.pop(dialogContext);

                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Password changed successfully.',
                                ),
                              ),
                            );
                          } on FirebaseAuthException catch (e) {
                            setDialogState(() {
                              saving = false;
                            });

                            String message = 'Unable to change password.';

                            if (e.code == 'wrong-password') {
                              message = 'Current password is incorrect.';
                            } else if (e.code == 'invalid-credential') {
                              message = 'Current password is incorrect.';
                            } else if (e.code == 'weak-password') {
                              message = 'The new password is too weak.';
                            } else if (e.code == 'requires-recent-login') {
                              message =
                                  'Please log in again and try changing your password.';
                            }

                            showError(
                              context,
                              message,
                            );
                          } catch (e) {
                            setDialogState(() {
                              saving = false;
                            });

                            showError(
                              context,
                              ApiService.errorMessage(e),
                            );
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Change'),
                ),
              ],
            );
          },
        );
      },
    );

    currentController.dispose();
    newController.dispose();
    confirmController.dispose();
  }

  Future<void> logout() async {
    await ApiService.logout();

    if (!mounted) return;

    context.go('/login');
  }

  Future<void> confirmLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Log out?'),
          content: const Text(
            'Are you sure you want to log out of CampusFind?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await logout();
    }
  }

  void showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'CampusFind',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        height: 48,
        width: 48,
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.search,
          color: AppColors.primary,
        ),
      ),
      children: const [
        Text(
          'CampusFind is an AI-powered college lost and found system designed to help students and staff recover lost belongings within campus.',
        ),
        SizedBox(height: 14),
        Text(
          'Lost something? Find it on campus.',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  void showPrivacyInfo() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            20,
            8,
            20,
            30,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Privacy & Security',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                _privacyRow(
                  Icons.lock_outline,
                  'Secure authentication',
                  'Your account uses authenticated access to protect CampusFind features.',
                ),
                _privacyRow(
                  Icons.visibility_off_outlined,
                  'Private information',
                  'Personal account information should only be displayed where required for CampusFind functionality.',
                ),
                _privacyRow(
                  Icons.location_on_outlined,
                  'Location data',
                  'Location information is used for campus item reporting and location-based features.',
                ),
                _privacyRow(
                  Icons.security_outlined,
                  'Account security',
                  'Keep your password private and do not share your account credentials with others.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _privacyRow(
    IconData icon,
    String title,
    String description,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 18,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget settingSwitch({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Card(
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.primary,
        secondary: Icon(
          icon,
          color: AppColors.primary,
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.muted,
          ),
        ),
      ),
    );
  }

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 4,
        bottom: 8,
        top: 8,
      ),
      child: Text(
        title,
        style: AppText.heading,
      ),
    );
  }

  Widget navigationTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(
          icon,
          color: iconColor ?? AppColors.primary,
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
        ),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          18,
          10,
          18,
          35,
        ),
        children: [
          sectionTitle('Notifications'),
          settingSwitch(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Receive CampusFind alerts and updates',
            value: notifications,
            onChanged: (value) {
              setState(() {
                notifications = value;

                if (!value) {
                  aiMatches = false;
                  messages = false;
                  claimUpdates = false;
                }
              });
            },
          ),
          settingSwitch(
            icon: Icons.auto_awesome_outlined,
            title: 'AI Match Alerts',
            subtitle: 'Get notified when a potential match is detected',
            value: aiMatches,
            onChanged: notifications
                ? (value) {
                    setState(() {
                      aiMatches = value;
                    });
                  }
                : null,
          ),
          settingSwitch(
            icon: Icons.chat_bubble_outline,
            title: 'Message Notifications',
            subtitle: 'Receive alerts for new messages',
            value: messages,
            onChanged: notifications
                ? (value) {
                    setState(() {
                      messages = value;
                    });
                  }
                : null,
          ),
          settingSwitch(
            icon: Icons.verified_user_outlined,
            title: 'Claim Updates',
            subtitle: 'Receive updates about your item claims',
            value: claimUpdates,
            onChanged: notifications
                ? (value) {
                    setState(() {
                      claimUpdates = value;
                    });
                  }
                : null,
          ),
          const SizedBox(height: 12),
          sectionTitle('Location'),
          settingSwitch(
            icon: Icons.location_on_outlined,
            title: 'Location Services',
            subtitle: 'Allow location-based CampusFind features',
            value: locationServices,
            onChanged: (value) {
              setState(() {
                locationServices = value;
              });
            },
          ),
          const SizedBox(height: 12),
          sectionTitle('Appearance'),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.brightness_6_outlined,
                color: AppColors.primary,
              ),
              title: const Text(
                'Appearance',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'CampusFind currently follows the app theme',
                style: TextStyle(
                  fontSize: 12,
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right,
              ),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text('Appearance'),
                      content: const Text(
                        'Theme customization can be enabled from the main app theme configuration.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          sectionTitle('Security'),
          navigationTile(
            icon: Icons.lock_reset_outlined,
            title: 'Change Password',
            subtitle: 'Update your CampusFind account password',
            onTap: changePassword,
          ),
          navigationTile(
            icon: Icons.shield_outlined,
            title: 'Privacy & Security',
            subtitle: 'View information about account and data protection',
            onTap: showPrivacyInfo,
          ),
          const SizedBox(height: 12),
          sectionTitle('About'),
          navigationTile(
            icon: Icons.info_outline,
            title: 'About CampusFind',
            subtitle: 'Application information and version',
            onTap: showAbout,
          ),
          navigationTile(
            icon: Icons.help_outline,
            title: 'Help & FAQ',
            subtitle: 'Get help with CampusFind features',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HelpScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          sectionTitle('Account'),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.logout,
                color: Colors.redAccent,
              ),
              title: const Text(
                'Log Out',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'Sign out of your CampusFind account',
                style: TextStyle(
                  fontSize: 12,
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right,
              ),
              onTap: confirmLogout,
            ),
          ),
          const SizedBox(height: 30),
          const Center(
            child: Text(
              'CampusFind',
              style: TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 5),
          const Center(
            child: Text(
              'Lost something? Find it on campus.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
