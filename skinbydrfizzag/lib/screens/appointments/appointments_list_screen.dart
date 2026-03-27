import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/appointment_model.dart';
import '../../services/appointment_service.dart';
import '../../services/auth_service.dart';

class AppointmentsListScreen extends StatefulWidget {
  const AppointmentsListScreen({super.key});

  @override
  State<AppointmentsListScreen> createState() => _AppointmentsListScreenState();
}

class _AppointmentsListScreenState extends State<AppointmentsListScreen> {
  final AppointmentService _appointmentService = AppointmentService();

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUserId;

    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text('User not authenticated')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'My Appointments',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
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

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No appointments found',
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
              ),
            );
          }

          // The rest of the build method remains the same...

          final allAppointments = snapshot.data ?? [];
          final upcomingAppointments = allAppointments.where((appointment) {
            DateTime appointmentDateTime = DateTime.now();
            try {
              final dateParts = appointment.appointmentDate.split('-');
              final timeParts = appointment.appointmentTime.split(':');
              if (dateParts.length == 3 && timeParts.length >= 2) {
                final year = int.parse(dateParts[0]);
                final month = int.parse(dateParts[1]);
                final day = int.parse(dateParts[2]);
                final hour = int.parse(timeParts[0]);
                final minute = int.parse(timeParts[1]);
                appointmentDateTime = DateTime(year, month, day, hour, minute);
              }
            } catch (e) {
              debugPrint('Error parsing appointment date: $e');
            }

            // Return appointments that are booked/confirmed and in the future
            return (appointment.status == 'booked' ||
                    appointment.status == 'confirmed') &&
                appointmentDateTime.isAfter(DateTime.now());
          }).toList();

          // Sort upcoming appointments by date/time (earliest first)
          upcomingAppointments.sort((a, b) {
            DateTime dateTimeA = DateTime.now();
            DateTime dateTimeB = DateTime.now();

            try {
              final datePartsA = a.appointmentDate.split('-');
              final timePartsA = a.appointmentTime.split(':');
              if (datePartsA.length == 3 && timePartsA.length >= 2) {
                final yearA = int.parse(datePartsA[0]);
                final monthA = int.parse(datePartsA[1]);
                final dayA = int.parse(datePartsA[2]);
                final hourA = int.parse(timePartsA[0]);
                final minuteA = int.parse(timePartsA[1]);
                dateTimeA = DateTime(yearA, monthA, dayA, hourA, minuteA);
              }

              final datePartsB = b.appointmentDate.split('-');
              final timePartsB = b.appointmentTime.split(':');
              if (datePartsB.length == 3 && timePartsB.length >= 2) {
                final yearB = int.parse(datePartsB[0]);
                final monthB = int.parse(datePartsB[1]);
                final dayB = int.parse(datePartsB[2]);
                final hourB = int.parse(timePartsB[0]);
                final minuteB = int.parse(timePartsB[1]);
                dateTimeB = DateTime(yearB, monthB, dayB, hourB, minuteB);
              }
            } catch (e) {
              debugPrint('Error parsing appointment date for sorting: $e');
            }

            return dateTimeA.compareTo(dateTimeB);
          });

          // Combine upcoming appointments first, then past appointments
          final appointments = [
            ...upcomingAppointments,
            ...allAppointments.where((appointment) {
              DateTime appointmentDateTime = DateTime.now();
              try {
                final dateParts = appointment.appointmentDate.split('-');
                final timeParts = appointment.appointmentTime.split(':');
                if (dateParts.length == 3 && timeParts.length >= 2) {
                  final year = int.parse(dateParts[0]);
                  final month = int.parse(dateParts[1]);
                  final day = int.parse(dateParts[2]);
                  final hour = int.parse(timeParts[0]);
                  final minute = int.parse(timeParts[1]);
                  appointmentDateTime = DateTime(
                    year,
                    month,
                    day,
                    hour,
                    minute,
                  );
                }
              } catch (e) {
                debugPrint('Error parsing appointment date: $e');
              }

              // Past appointments or canceled/completed
              return (appointment.status != 'booked' &&
                      appointment.status != 'confirmed') ||
                  appointmentDateTime.isBefore(DateTime.now());
            }),
          ];

          return RefreshIndicator(
            onRefresh: () async {
              // The StreamBuilder handles real-time updates automatically
              // This refresh indicator is just for visual feedback
              return Future<void>.delayed(const Duration(milliseconds: 500));
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: appointments.length,
              itemBuilder: (context, index) {
                final appointment = appointments[index];
                return _buildAppointmentCard(appointment);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppointmentCard(AppointmentModel appointment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    appointment.procedureName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(appointment.status).withAlpha(51),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    appointment.status.toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(appointment.status),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.calendar_today,
              'Date: ${appointment.appointmentDate}',
            ),
            const SizedBox(height: 4),
            _buildInfoRow(
              Icons.access_time,
              'Time: ${appointment.appointmentTime}',
            ),
            const SizedBox(height: 4),
            _buildInfoRow(
              Icons.medical_services,
              'Doctor ID: ${appointment.doctorId}',
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Booked on: ${_formatDate(appointment.createdAt ?? DateTime.now())}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: AppColors.textSecondary)),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'booked':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'missed':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
