import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../constants/colors.dart';
import 'manage_users_screen.dart';
import 'manage_about_us_screen.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Admin Panel", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AuthService>().signOut();
            },
          ),
        ],
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(20),
        crossAxisCount: 2,
        mainAxisSpacing: 20,
        crossAxisSpacing: 20,
        children: [
          _buildAdminCard(
            context,
            "Manage Users",
            Icons.people,
            Colors.blue,
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageUsersScreen())),
          ),
          _buildAdminCard(
            context,
            "Manage Procedures",
            Icons.medical_services,
            Colors.green,
            () {
              // Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageProceduresScreen()));
            },
          ),
          _buildAdminCard(
            context,
            "View Appointments",
            Icons.calendar_today,
            Colors.orange,
            () {
              // Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminAppointmentsScreen()));
            },
          ),
          _buildAdminCard(
            context,
            "Manage About Us",
            Icons.info_outline,
            Colors.purple,
            () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageAboutUsScreen()));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAdminCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, size: 30, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
