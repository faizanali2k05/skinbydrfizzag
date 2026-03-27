import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants/colors.dart';
import '../../constants/styles.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
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

  Future<void> _addUser(
    String name,
    String email,
    String password,
    String phone,
  ) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final error = await authService.signUp(
      name: name,
      email: email,
      phone: phone,
      password: password,
    );
    if (error != null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $error')));
      }
      return;
    }
    // No need to manually reload, StreamBuilder handles it
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User created successfully")),
      );
    }
  }

  Future<void> _updateUser(String uid, Map<String, dynamic> data) async {
    try {
      await Supabase.instance.client
          .from('profiles')
          .update(data)
          .eq('id', uid);
      // No need to manually reload
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
        // No need to manually reload
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

  void _showAddUserDialog({UserModel? user}) {
    final nameController = TextEditingController(text: user?.displayName ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');
    final passwordController = TextEditingController();
    final phoneController = TextEditingController(
      text: user?.phoneNumber ?? '',
    );
    final isEditing = user != null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? "Edit User" : "Add User"),
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
              if (!isEditing)
                TextField(
                  controller: passwordController,
                  decoration: AppStyles.inputDecoration("Password"),
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
              final password = passwordController.text.trim();
              final phone = phoneController.text.trim();

              if (name.isEmpty || email.isEmpty) return;
              if (!isEditing && password.isEmpty) return;

              if (isEditing) {
                final updates = {
                  'full_name': name,
                  'email': email,
                  'phone': phone,
                };
                _updateUser(user.uid, updates);
              } else {
                _addUser(name, email, password, phone);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(
              isEditing ? "Save" : "Add",
              style: const TextStyle(color: Colors.white),
            ),
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
                _showAddUserDialog(user: user);
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock, color: Colors.amber),
              title: const Text("Change Password"),
              onTap: () {
                Navigator.pop(context);
                _showChangePasswordDialog(user);
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
                title: const Text("Deactivate User"),
                onTap: () => _updateUser(user.uid, {'status': 'blocked'}),
              )
            else
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: const Text("Activate User"),
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

              // Perform async operation
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
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text('Error: $error')),
                );
              } else {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Password updated successfully')),
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
        title: const Text(
          "Manage Users",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primary),
            onPressed: () {
              _showAddUserDialog();
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              decoration: AppStyles.inputDecoration(
                "Search by name or email...",
                prefixIcon: Icons.search,
              ).copyWith(
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
            ),
          ),
        ),
      ),

      body: StreamBuilder<List<UserModel>>(
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
            final nameMatch = u.displayName.toLowerCase().contains(_searchQuery);
            final emailMatch = u.email.toLowerCase().contains(_searchQuery);
            return nameMatch || emailMatch;
          }).toList();

          if (users.isEmpty) {
            return const Center(child: Text("No users found."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return _buildUserCard(user);
            },
          );

        },
      ),
    );
  }

  Widget _buildUserCard(UserModel user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: AppStyles.cardDecoration,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                user.displayName.isNotEmpty
                    ? user.displayName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName.isNotEmpty ? user.displayName : "No Name",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                // Removed email display as requested
                const SizedBox(height: 4),
                if (user.createdAt != null)
                  Text(
                    "Created: ${_formatDate(user.createdAt!)}",
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),

                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildBadge(
                      user.role,
                      user.role == 'admin' ? Colors.purple : Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    _buildBadge(
                      user.status,
                      user.status == 'active' ? Colors.green : Colors.red,
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.grey),
            onPressed: () {
              _showUserOptions(user);
            },
          ),
        ],
      ),
    );
  }



  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      "JAN",
      "FEB",
      "MAR",
      "APR",
      "MAY",
      "JUN",
      "JUL",
      "AUG",
      "SEP",
      "OCT",
      "NOV",
      "DEC",
    ];
    return "${months[date.month - 1]} ${date.day}, ${date.year} at ${_formatTime(date)}";
  }

  String _formatTime(DateTime date) {
    final hour = date.hour > 12
        ? date.hour - 12
        : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return "$hour:$minute $period";
  }
}
