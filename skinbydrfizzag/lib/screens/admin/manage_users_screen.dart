import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants/colors.dart';
import '../../constants/styles.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/soft_card.dart';
import '../appointments/book_appointment_screen.dart';
import '../profile/user_profile_screen.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _updateUser(String uid, Map<String, dynamic> data) async {
    try {
      await Supabase.instance.client
          .from('profiles')
          .update(data)
          .eq('id', uid);
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating user: $e')));
      }
    }
  }

  Future<void> _deleteUser(String uid) async {
    final confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete User"),
        content: const Text("Are you sure? This cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Yes", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client.from('profiles').delete().eq('id', uid);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting user: $e')));
        }
      }
    }
  }

  void _showEditUserDialog(UserModel user) {
    final nameController = TextEditingController(text: user.displayName);
    final emailController = TextEditingController(text: user.email);
    final phoneController = TextEditingController(text: user.phoneNumber);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit User"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: AppStyles.inputDecoration("Full Name"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emailController,
                decoration: AppStyles.inputDecoration("Email"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneController,
                decoration: AppStyles.inputDecoration("Phone Number"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final email = emailController.text.trim();
              final phone = phoneController.text.trim();

              if (name.isEmpty || email.isEmpty) return;
              final updates = {
                'full_name': name,
                'email': email,
                'phone': phone,
              };
              _updateUser(user.uid, updates);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text("Save", style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showUserOptions(UserModel user) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person, color: AppColors.primary),
              title: const Text("View Profile"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserProfileScreen(userModel: user),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text("Edit User"),
              onTap: () {
                Navigator.pop(context);
                _showEditUserDialog(user);
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock, color: Colors.amber),
              // Show different label for unregistered (WhatsApp-only) users
              title: Text(
                _isUnregisteredUser(user)
                    ? "Register & Set Password"
                    : "Change Password",
              ),
              onTap: () {
                Navigator.pop(context);
                if (_isUnregisteredUser(user)) {
                  _showRegisterUserDialog(user);
                } else {
                  _showChangePasswordDialog(user);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month, color: Colors.green),
              title: const Text("Assign Appointment"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BookAppointmentScreen(
                      targetUserId: user.uid,
                      targetUserName: user.displayName,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(
                Icons.admin_panel_settings,
                color: user.role == 'admin' ? Colors.red : Colors.green,
              ),
              title: Text(
                user.role == 'admin' ? "Remove Admin Role" : "Make Admin",
              ),
              onTap: () => _updateUser(user.uid, {
                'role': user.role == 'admin' ? 'user' : 'admin',
              }),
            ),
            if (user.status == 'active')
              ListTile(
                leading: const Icon(Icons.block, color: Colors.orange),
                title: const Text("Active/Deactive"),
                onTap: () => _updateUser(user.uid, {'status': 'deactive'}),
              )
            else
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: const Text("Active/Deactive"),
                onTap: () => _updateUser(user.uid, {'status': 'active'}),
              ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text("Delete User"),
              onTap: () => _deleteUser(user.uid),
            ),
          ],
        ),
      ),
    );
  }

  /// WhatsApp-only users have no Supabase Auth account.
  /// The admin must give them an email + password first to enable login,
  /// then the normal "Change Password" flow works via the backend API.
  void _showRegisterUserDialog(UserModel user) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Register ${user.displayName}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This is a WhatsApp-only user with no login account. '
                        'Provide an email & password to register them so they can log in.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: AppStyles.inputDecoration('Email address'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: AppStyles.inputDecoration('New Password'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: AppStyles.inputDecoration('Confirm Password'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              final password = passwordController.text.trim();
              final confirm = confirmController.text.trim();

              if (email.isEmpty || password.isEmpty || confirm.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('All fields are required')),
                );
                return;
              }
              if (password != confirm) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Passwords do not match')),
                );
                return;
              }
              if (password.length < 6) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('Password must be at least 6 characters'),
                  ),
                );
                return;
              }

              // Create a Supabase Auth account via the backend admin API. The
              // backend also folds the WhatsApp-only profile (and its WA
              // conversations) onto the new authenticated profile so the user
              // does not appear twice.
              final authService = Provider.of<AuthService>(
                dialogContext,
                listen: false,
              );
              final error = await authService.signUp(
                name: user.displayName,
                email: email,
                phone: user.phoneNumber,
                password: password,
                existingProfileId: user.uid,
              );

              if (!dialogContext.mounted) return;

              if (error != null) {
                ScaffoldMessenger.of(
                  dialogContext,
                ).showSnackBar(SnackBar(content: Text('Error: $error')));
                return;
              }

              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'User registered! They can now log in with email & password.',
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text(
              'Register User',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(UserModel user) {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text("Change Password for ${user.displayName}"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: AppStyles.inputDecoration("New Password"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: AppStyles.inputDecoration("Confirm Password"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final password = passwordController.text.trim();
              final confirm = confirmController.text.trim();

              if (password.isEmpty || confirm.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Passwords cannot be empty')),
                );
                return;
              }

              if (password != confirm) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Passwords do not match')),
                );
                return;
              }

              final authService = Provider.of<AuthService>(
                dialogContext,
                listen: false,
              );
              final error = await authService.updateUserPassword(
                user.uid,
                password,
              );

              if (!dialogContext.mounted) return;

              if (error != null) {
                ScaffoldMessenger.of(
                  dialogContext,
                ).showSnackBar(SnackBar(content: Text('Error: $error')));
              } else {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('Password updated successfully'),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text("Update", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Manage Users'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) =>
                  setState(() => _searchQuery = value.trim().toLowerCase()),
              decoration:
                  AppStyles.inputDecoration(
                    'Search by name, email or phone',
                    prefixIcon: Icons.search,
                  ).copyWith(
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          ),
                  ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: Provider.of<AuthService>(
                context,
                listen: false,
              ).getAllProfilesStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final allUsers = snapshot.data ?? [];
                final users = allUsers.where((u) {
                  if (_searchQuery.isEmpty) return true;
                  return u.displayName.toLowerCase().contains(_searchQuery) ||
                      u.name.toLowerCase().contains(_searchQuery) ||
                      u.email.toLowerCase().contains(_searchQuery) ||
                      u.phone.toLowerCase().contains(_searchQuery);
                }).toList();

                if (users.isEmpty) {
                  return const EmptyState(
                    icon: Icons.people_alt_outlined,
                    title: 'No users found',
                    message: 'Try a different search term.',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: users.length,
                  itemBuilder: (_, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildUserCard(users[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(UserModel user) {
    final initial = user.displayName.isNotEmpty
        ? user.displayName[0].toUpperCase()
        : (user.name.isNotEmpty ? user.name[0].toUpperCase() : '?');
    final displayName = user.displayName.isNotEmpty
        ? user.displayName
        : (user.name.isNotEmpty ? user.name : 'Unnamed user');
    return SoftCard(
      onTap: () => _showUserOptions(user),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
            ),
            padding: const EdgeInsets.all(2),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
                image: user.photoUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(user.photoUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: user.photoUrl.isEmpty
                  ? Center(
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (user.email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppStyles.bodySmall,
                  ),
                ],
                if (user.phone.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(user.phone, style: AppStyles.bodySmall),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildBadge(
                      user.role,
                      user.role == 'admin'
                          ? AppColors.accentDark
                          : AppColors.info,
                    ),
                    _buildBadge(
                      user.status,
                      user.status == 'active'
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                    if (_isUnregisteredUser(user))
                      _buildBadge('WhatsApp only', AppColors.warning),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: AppColors.textSecondary,
            ),
            onPressed: () => _showUserOptions(user),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        text.isEmpty ? '—' : text[0].toUpperCase() + text.substring(1),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  /// Returns true when the profile was created by WhatsApp webhook (no email).
  bool _isUnregisteredUser(UserModel user) {
    return user.email.trim().isEmpty;
  }
}
