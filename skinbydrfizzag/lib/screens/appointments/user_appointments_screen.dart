import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../constants/styles.dart';
import '../../models/appointment_model.dart';
import '../../services/appointment_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/soft_card.dart';
import '../../widgets/status_chip.dart';
import 'appointment_detail_screen.dart';

class UserAppointmentsScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final bool showUpcomingByDefault;

  const UserAppointmentsScreen({
    super.key,
    required this.userId,
    required this.userName,
    this.showUpcomingByDefault = true,
  });

  @override
  State<UserAppointmentsScreen> createState() =>
      _UserAppointmentsScreenState();
}

class _UserAppointmentsScreenState extends State<UserAppointmentsScreen> {
  final AppointmentService _appointmentService = AppointmentService();
  late bool _isUpcoming = widget.showUpcomingByDefault;

  DateTime? _appointmentDateTime(AppointmentModel a) {
    try {
      return DateTime.parse('${a.appointmentDate} ${a.appointmentTime}');
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.userName.isEmpty
              ? 'Appointments'
              : '${widget.userName}\'s appointments',
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  Expanded(child: _segment('Upcoming', true)),
                  Expanded(child: _segment('Previous', false)),
                ],
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<AppointmentModel>>(
              stream:
                  _appointmentService.getUserAppointmentsStreamByUserId(
                widget.userId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final all = snapshot.data ?? [];
                final filtered = all.where((a) {
                  final dt = _appointmentDateTime(a);
                  if (dt == null) return !_isUpcoming;
                  return _isUpcoming
                      ? !dt.isBefore(DateTime.now())
                      : dt.isBefore(DateTime.now());
                }).toList()
                  ..sort((a, b) {
                    final da = _appointmentDateTime(a) ?? DateTime(0);
                    final db = _appointmentDateTime(b) ?? DateTime(0);
                    return _isUpcoming
                        ? da.compareTo(db)
                        : db.compareTo(da);
                  });

                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: _isUpcoming
                        ? Icons.event_available_outlined
                        : Icons.history_rounded,
                    title: _isUpcoming
                        ? 'No upcoming appointments'
                        : 'No previous appointments',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _appointmentTile(filtered[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _segment(String label, bool upcoming) {
    final selected = _isUpcoming == upcoming;
    return GestureDetector(
      onTap: () => setState(() => _isUpcoming = upcoming),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _appointmentTile(AppointmentModel a) {
    return SoftCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AppointmentDetailScreen(appointmentId: a.id),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
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
                  a.procedureName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppStyles.h3.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  '${a.appointmentDate} · ${a.appointmentTime}',
                  style: AppStyles.bodySmall,
                ),
              ],
            ),
          ),
          StatusChip(status: a.status),
        ],
      ),
    );
  }
}
