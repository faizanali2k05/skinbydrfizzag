import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../constants/styles.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user_model.dart';

import '../../models/appointment_model.dart';
import '../../services/appointment_service.dart';
import '../../services/auth_service.dart';
import '../appointments/book_appointment_screen.dart';
import 'edit_profile_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String? userId; // If null, show current user
  final UserModel? userModel; // Optional: if already fetched

  const UserProfileScreen({super.key, this.userId, this.userModel});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final AppointmentService _appointmentService = AppointmentService();
  UserModel? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    if (widget.userModel != null) {
      setState(() {
        _user = widget.userModel;
        _isLoading = false;
      });
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final uid = widget.userId ?? authService.currentUserId;

    if (uid != null) {
      final user = await authService.getUserByUid(uid);

      if (mounted) {
        setState(() {
          _user = user;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Profile")),
        body: const Center(child: Text("User not found")),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_user!.name, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 24),
            _buildActionButtons(),
            const SizedBox(height: 24),
            const Text("Upcoming Appointments", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildAppointmentList(isUpcoming: true),
            const SizedBox(height: 24),
            const Text("Past Appointments & Procedures", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildAppointmentList(isUpcoming: false),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppStyles.cardDecoration,
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.primary.withAlpha(50),
            backgroundImage: _user!.photoUrl.isNotEmpty ? NetworkImage(_user!.photoUrl) : null,
            child: _user!.photoUrl.isEmpty
                ? Text(_user!.name[0].toUpperCase(), style: const TextStyle(fontSize: 30, color: AppColors.primary))
                : null,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_user!.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(_user!.email, style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 4),
                Text(_user!.phone, style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _user!.status == 'active' ? Colors.green.withAlpha(30) : Colors.red.withAlpha(30),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _user!.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _user!.status == 'active' ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const EditProfileScreen()),
            ),
            icon: const Icon(Icons.edit, size: 18),
            label: const Text("Edit Profile"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BookAppointmentScreen(
                  targetUserId: _user!.uid,
                  targetUserName: _user!.name,
                ),
              ),
            ),
            icon: const Icon(Icons.add_task, size: 18),
            label: const Text("New Appointment"),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppointmentList({required bool isUpcoming}) {
    return StreamBuilder<List<AppointmentModel>>(
      stream: _appointmentService.getUserAppointmentsStreamByUserId(_user!.uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final now = DateTime.now();
        final appointments = snapshot.data!.where((a) {
          try {
            final date = DateTime.parse(a.appointmentDate);
            return isUpcoming ? date.isAfter(now) || date.isAtSameMomentAs(now) : date.isBefore(now);
          } catch (_) {
            return !isUpcoming; // Fallback
          }
        }).toList();

        if (appointments.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                isUpcoming ? "No upcoming appointments" : "No previous record",
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        return Column(
          children: appointments.map((a) => _buildAppointmentItem(a)).toList(),
        );
      },
    );
  }

  Widget _buildAppointmentItem(AppointmentModel appointment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppStyles.cardDecoration,
      child: InkWell(
        onTap: () {
          // Navigate to appointment detail
        },
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.calendar_today, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(appointment.procedureName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text("${appointment.appointmentDate} at ${appointment.appointmentTime}", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  if (appointment.clinicLocation.isNotEmpty)
                    Text(appointment.clinicLocation, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

extension on AppointmentService {
  Stream<List<AppointmentModel>> getUserAppointmentsStreamByUserId(String uid) {
    return Supabase.instance.client
        .from('appointments')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('scheduled_at', ascending: false)
        .map((event) {
          return event
              .map((e) => AppointmentModel.fromMap(e, e['id'] as String))
              .toList();
        });
  }
}
