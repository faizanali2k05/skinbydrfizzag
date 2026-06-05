import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../constants/styles.dart';
import '../../models/appointment_model.dart';
import '../../models/user_model.dart';
import '../../services/appointment_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/soft_card.dart';
import '../../widgets/status_chip.dart';
import '../appointments/appointment_detail_screen.dart';
import '../appointments/book_appointment_screen.dart';
import '../appointments/user_appointments_screen.dart';
import 'edit_profile_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String? userId;
  final UserModel? userModel;

  const UserProfileScreen({super.key, this.userId, this.userModel});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final AppointmentService _appointmentService = AppointmentService();
  UserModel? _user;
  bool _isLoading = true;
  bool _isViewingOwnProfile = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (widget.userModel != null) {
      setState(() {
        _user = widget.userModel;
        _isViewingOwnProfile =
            widget.userModel!.uid == authService.currentUserId;
        _isLoading = false;
      });
      return;
    }
    final uid = widget.userId ?? authService.currentUserId;
    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    final user = await authService.getUserByUid(uid);
    if (!mounted) return;
    setState(() {
      _user = user;
      _isViewingOwnProfile = uid == authService.currentUserId;
      _isLoading = false;
    });
  }

  DateTime? _appointmentDateTime(AppointmentModel a) {
    try {
      return DateTime.parse(
        '${a.appointmentDate} ${a.appointmentTime}',
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const EmptyState(
          icon: Icons.person_off_outlined,
          title: 'User not found',
        ),
      );
    }

    final user = _user!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(user.name.isEmpty ? 'Profile' : user.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          _buildHeader(user),
          const SizedBox(height: 16),
          _buildActionRow(user),
          const SizedBox(height: 16),
          _buildQuickNav(user),
          const SizedBox(height: 22),
          Text('Upcoming appointments', style: AppStyles.h3),
          const SizedBox(height: 10),
          _buildList(user, isUpcoming: true),
          const SizedBox(height: 22),
          Text('Past visits', style: AppStyles.h3),
          const SizedBox(height: 10),
          _buildList(user, isUpcoming: false),
        ],
      ),
    );
  }

  Widget _buildHeader(UserModel user) {
    final initial =
        user.name.trim().isNotEmpty ? user.name.trim()[0].toUpperCase() : '?';
    return SoftCard(
      child: Row(
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
            ),
            padding: const EdgeInsets.all(2.5),
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
                          fontSize: 28,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
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
                  user.name.isEmpty ? 'User' : user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppStyles.h2,
                ),
                if (user.email.isNotEmpty) ...[
                  const SizedBox(height: 4),
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
                StatusChip(status: user.status),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(UserModel user) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isViewingOwnProfile
                ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EditProfileScreen(),
                      ),
                    )
                : null,
            icon: const Icon(Icons.edit_rounded, size: 18, color: Colors.white),
            label: const Text(
              'Edit Profile',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BookAppointmentScreen(
                  targetUserId: user.uid,
                  targetUserName: user.name,
                ),
              ),
            ),
            icon: const Icon(Icons.add_task_rounded, size: 18),
            label: const Text('New booking'),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickNav(UserModel user) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UserAppointmentsScreen(
                  userId: user.uid,
                  userName: user.name,
                  showUpcomingByDefault: true,
                ),
              ),
            ),
            icon: const Icon(Icons.upcoming_rounded, size: 18),
            label: const Text('Upcoming'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UserAppointmentsScreen(
                  userId: user.uid,
                  userName: user.name,
                  showUpcomingByDefault: false,
                ),
              ),
            ),
            icon: const Icon(Icons.history_rounded, size: 18),
            label: const Text('Past'),
          ),
        ),
      ],
    );
  }

  Widget _buildList(UserModel user, {required bool isUpcoming}) {
    return StreamBuilder<List<AppointmentModel>>(
      stream: _appointmentService.getUserAppointmentsStreamByUserId(user.uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final now = DateTime.now();
        final list = snapshot.data!.where((a) {
          final dt = _appointmentDateTime(a);
          if (dt == null) return !isUpcoming;
          return isUpcoming ? !dt.isBefore(now) : dt.isBefore(now);
        }).toList()
          ..sort((a, b) {
            final da = _appointmentDateTime(a) ?? DateTime(0);
            final db = _appointmentDateTime(b) ?? DateTime(0);
            return isUpcoming ? da.compareTo(db) : db.compareTo(da);
          });

        if (list.isEmpty) {
          return SoftCard(
            color: AppColors.surfaceMuted,
            padding: const EdgeInsets.symmetric(vertical: 22),
            child: Center(
              child: Text(
                isUpcoming ? 'No upcoming appointments' : 'No previous record',
                style: AppStyles.bodyMedium,
              ),
            ),
          );
        }

        return Column(
          children: list.map((a) => _buildAppointmentTile(a)).toList(),
        );
      },
    );
  }

  Widget _buildAppointmentTile(AppointmentModel appointment) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AppointmentDetailScreen(
              appointmentId: appointment.id,
            ),
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.event_note_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appointment.procedureName,
                    style: AppStyles.h3.copyWith(fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${appointment.appointmentDate} · ${appointment.appointmentTime}',
                    style: AppStyles.bodySmall,
                  ),
                  if (appointment.clinicLocation.isNotEmpty)
                    Text(
                      appointment.clinicLocation,
                      style: AppStyles.bodySmall,
                    ),
                ],
              ),
            ),
            StatusChip(status: appointment.status),
          ],
        ),
      ),
    );
  }
}
