import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../constants/styles.dart';
import '../../models/appointment_model.dart';
import '../../models/procedure_model.dart';
import '../../models/user_model.dart';
import '../../services/appointment_service.dart';
import '../../services/auth_service.dart';
import '../../services/procedure_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/soft_card.dart';
import '../../widgets/status_chip.dart';
import 'reschedule_screen.dart';

class AppointmentDetailScreen extends StatelessWidget {
  final String appointmentId;
  const AppointmentDetailScreen({super.key, required this.appointmentId});

  @override
  Widget build(BuildContext context) {
    final appointmentService =
        Provider.of<AppointmentService>(context, listen: false);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Appointment Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<AppointmentModel?>(
        future: appointmentService.getAppointment(appointmentId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const EmptyState(
              icon: Icons.event_busy_outlined,
              title: 'Appointment not found',
              message: 'It may have been deleted or already completed.',
            );
          }

          final appointment = snapshot.data!;
          final authService =
              Provider.of<AuthService>(context, listen: false);

          return FutureBuilder<UserModel?>(
            future: authService.getUserByUid(appointment.userId),
            builder: (context, userSnapshot) {
              final assignedUser = userSnapshot.data;
              return FutureBuilder<ProcedureModel?>(
                future:
                    ProcedureService().getProcedureById(appointment.procedureId),
                builder: (context, procedureSnapshot) {
                  final procedure = procedureSnapshot.data;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    children: [
                      _buildHeader(appointment),
                      const SizedBox(height: 16),
                      if (procedure != null) ...[
                        Text('Procedure', style: AppStyles.h3),
                        const SizedBox(height: 10),
                        SoftCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _detailRow(
                                Icons.category_rounded,
                                'Category',
                                procedure.category,
                              ),
                              if (procedure.description.isNotEmpty) ...[
                                const Divider(height: 22),
                                _detailRow(
                                  Icons.description_outlined,
                                  'Details',
                                  procedure.description,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Text('When & where', style: AppStyles.h3),
                      const SizedBox(height: 10),
                      SoftCard(
                        child: Column(
                          children: [
                            _detailRow(
                              Icons.calendar_today_rounded,
                              'Date',
                              appointment.appointmentDate,
                            ),
                            const Divider(height: 22),
                            _detailRow(
                              Icons.access_time_rounded,
                              'Time',
                              appointment.appointmentTime,
                            ),
                            const Divider(height: 22),
                            _detailRow(
                              Icons.location_on_outlined,
                              'Clinic',
                              appointment.clinicLocation.isEmpty
                                  ? 'Not specified'
                                  : appointment.clinicLocation,
                            ),
                            if (appointment.notes.isNotEmpty) ...[
                              const Divider(height: 22),
                              _detailRow(
                                Icons.notes_rounded,
                                'Notes',
                                appointment.notes,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Visit info', style: AppStyles.h3),
                      const SizedBox(height: 10),
                      SoftCard(
                        child: Column(
                          children: [
                            _detailRow(
                              Icons.confirmation_number_outlined,
                              'Visit Number',
                              appointment.visitNumber.toString(),
                            ),
                            const Divider(height: 22),
                            _detailRow(
                              Icons.repeat_rounded,
                              'Session Number',
                              appointment.sessionNumber.toString(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Patient', style: AppStyles.h3),
                      const SizedBox(height: 10),
                      SoftCard(
                        child: Column(
                          children: [
                            _detailRow(
                              Icons.person_outline_rounded,
                              'Name',
                              appointment.userName.isNotEmpty
                                  ? appointment.userName
                                  : (assignedUser?.name.isNotEmpty == true
                                      ? assignedUser!.name
                                      : 'Unknown'),
                            ),
                            const Divider(height: 22),
                            _detailRow(
                              Icons.email_outlined,
                              'Email',
                              assignedUser?.email.isNotEmpty == true
                                  ? assignedUser!.email
                                  : 'Not available',
                            ),
                            const Divider(height: 22),
                            _detailRow(
                              Icons.phone_outlined,
                              'Phone',
                              assignedUser?.phone.isNotEmpty == true
                                  ? assignedUser!.phone
                                  : 'Not available',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildActions(context, appointment, appointmentService),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeader(AppointmentModel appointment) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(60),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(48),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'APPOINTMENT',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              StatusChip(status: appointment.status),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            appointment.procedureName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${appointment.appointmentDate}  ·  ${appointment.appointmentTime}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActions(
    BuildContext context,
    AppointmentModel appointment,
    AppointmentService service,
  ) {
    final isCancellable = appointment.status == 'pending' ||
        appointment.status == 'booked' ||
        appointment.status == 'confirmed';
    if (!isCancellable) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    RescheduleScreen(appointmentId: appointment.id),
              ),
            ),
            icon: const Icon(Icons.event_repeat_rounded, size: 18),
            label: const Text('Reschedule'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Cancel appointment?'),
                  content: const Text(
                    'This will mark the appointment as cancelled.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Keep'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                final err = await service.cancelAppointment(appointment.id);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      err == null
                          ? 'Appointment cancelled.'
                          : 'Error: $err',
                    ),
                    backgroundColor:
                        err == null ? AppColors.textPrimary : AppColors.error,
                  ),
                );
                if (err == null) Navigator.pop(context);
              }
            },
            icon: const Icon(
              Icons.cancel_outlined,
              size: 18,
              color: AppColors.error,
            ),
            label: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.error),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: BorderSide(color: AppColors.error.withAlpha(80)),
            ),
          ),
        ),
      ],
    );
  }
}
