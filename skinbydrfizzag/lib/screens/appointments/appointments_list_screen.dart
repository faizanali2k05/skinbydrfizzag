import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../constants/styles.dart';
import '../../models/appointment_model.dart';
import '../../routes/app_routes.dart';
import '../../services/appointment_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/soft_card.dart';
import '../../widgets/status_chip.dart';
import 'appointment_detail_screen.dart';
import 'reschedule_screen.dart';

class AppointmentsListScreen extends StatefulWidget {
  const AppointmentsListScreen({super.key});

  @override
  State<AppointmentsListScreen> createState() =>
      _AppointmentsListScreenState();
}

class _AppointmentsListScreenState extends State<AppointmentsListScreen> {
  final AppointmentService _appointmentService = AppointmentService();

  DateTime? _parseDateTime(AppointmentModel a) {
    try {
      final d = a.appointmentDate.split('-');
      final t = a.appointmentTime.split(':');
      if (d.length == 3 && t.length >= 2) {
        return DateTime(
          int.parse(d[0]),
          int.parse(d[1]),
          int.parse(d[2]),
          int.parse(t[0]),
          int.parse(t[1]),
        );
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUserId;

    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view appointments.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Appointments'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppColors.primary),
            tooltip: 'Book new',
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.bookAppointment),
          ),
        ],
      ),
      body: StreamBuilder<List<AppointmentModel>>(
        stream: _appointmentService.getUserAppointmentsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final all = snapshot.data ?? [];
          if (all.isEmpty) {
            return EmptyState(
              icon: Icons.event_available_outlined,
              title: 'No appointments yet',
              message: 'Book your first visit and it will appear here.',
              actionLabel: 'Book Appointment',
              onAction: () => Navigator.pushNamed(
                context,
                AppRoutes.bookAppointment,
              ),
            );
          }

          final now = DateTime.now();
          final upcoming = <AppointmentModel>[];
          final past = <AppointmentModel>[];
          for (final a in all) {
            final dt = _parseDateTime(a) ?? DateTime(0);
            final isUpcomingStatus = a.status == 'pending' ||
                a.status == 'booked' ||
                a.status == 'confirmed';
            if (isUpcomingStatus && dt.isAfter(now)) {
              upcoming.add(a);
            } else {
              past.add(a);
            }
          }

          upcoming.sort((a, b) =>
              (_parseDateTime(a) ?? DateTime(0))
                  .compareTo(_parseDateTime(b) ?? DateTime(0)));
          past.sort((a, b) =>
              (_parseDateTime(b) ?? DateTime(0))
                  .compareTo(_parseDateTime(a) ?? DateTime(0)));

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              await Future<void>.delayed(const Duration(milliseconds: 400));
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                if (upcoming.isNotEmpty) ...[
                  _sectionLabel('Upcoming · ${upcoming.length}'),
                  const SizedBox(height: 8),
                  ...upcoming.map((a) => _buildCard(a, isUpcoming: true)),
                ],
                if (past.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _sectionLabel('Past · ${past.length}'),
                  const SizedBox(height: 8),
                  ...past.map((a) => _buildCard(a, isUpcoming: false)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: AppStyles.overline.copyWith(
          color: AppColors.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildCard(AppointmentModel appointment, {required bool isUpcoming}) {
    final dateTime = _parseDateTime(appointment);
    return SoftCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AppointmentDetailScreen(
            appointmentId: appointment.id,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _dateTile(dateTime),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment.procedureName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppStyles.h3,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          appointment.appointmentTime,
                          style: AppStyles.bodySmall,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  appointment.clinicLocation.isNotEmpty
                                      ? appointment.clinicLocation
                                      : 'Main clinic',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppStyles.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              StatusChip(status: appointment.status),
            ],
          ),
          if (isUpcoming) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RescheduleScreen(
                          appointmentId: appointment.id,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.event_repeat, size: 18),
                    label: const Text('Reschedule'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AppointmentDetailScreen(
                          appointmentId: appointment.id,
                        ),
                      ),
                    ),
                    icon: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Details',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _dateTile(DateTime? dt) {
    final day = dt?.day.toString() ?? '—';
    final month = dt != null ? _shortMonth(dt.month) : '';
    return Container(
      width: 56,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withAlpha(40)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            day,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            month,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  String _shortMonth(int m) {
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
    ];
    if (m < 1 || m > 12) return '';
    return months[m - 1];
  }
}
