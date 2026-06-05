import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../constants/styles.dart';
import '../../models/appointment_model.dart';
import '../../models/clinic_location_model.dart';
import '../../models/procedure_model.dart';
import '../../models/user_model.dart';
import '../../services/appointment_service.dart';
import '../../services/auth_service.dart';
import '../../services/clinic_location_service.dart';
import '../../services/procedure_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/soft_card.dart';
import '../../widgets/status_chip.dart';
import '../appointments/appointment_detail_screen.dart';

class ManageAppointmentsScreen extends StatefulWidget {
  const ManageAppointmentsScreen({super.key});

  @override
  State<ManageAppointmentsScreen> createState() =>
      _ManageAppointmentsScreenState();
}

class _ManageAppointmentsScreenState extends State<ManageAppointmentsScreen> {
  final AppointmentService _appointmentService = AppointmentService();
  int _selectedTabIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Manage Appointments'),
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
                    'Search by procedure, user or status',
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  Expanded(child: _segment('All appointments', 0)),
                  Expanded(child: _segment('Assign new', 1)),
                ],
              ),
            ),
          ),
          Expanded(
            child: _selectedTabIndex == 0
                ? _buildAppointmentsList()
                : _buildAssignAppointment(),
          ),
        ],
      ),
    );
  }

  Widget _segment(String label, int index) {
    final selected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = index),
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

  Widget _buildAppointmentsList() {
    return StreamBuilder<List<AppointmentModel>>(
      stream: _appointmentService.getAllAppointmentsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const EmptyState(
            icon: Icons.event_busy_outlined,
            title: 'No appointments yet',
            message: 'Bookings will appear here as patients schedule visits.',
          );
        }

        final allAppointments = snapshot.data ?? [];
        final appointments = allAppointments.where((a) {
          final procedureMatch = a.procedureName.toLowerCase().contains(
            _searchQuery,
          );
          final userMatch = a.userName.toLowerCase().contains(_searchQuery);
          final statusMatch = a.status.toLowerCase().contains(_searchQuery);
          final dateMatch = a.appointmentDate.toLowerCase().contains(
            _searchQuery,
          );
          return procedureMatch || userMatch || statusMatch || dateMatch;
        }).toList();

        if (appointments.isEmpty) {
          return const EmptyState(
            icon: Icons.search_off_rounded,
            title: 'No matching appointments',
            message: 'Try a different search term.',
          );
        }

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            await Future<void>.delayed(const Duration(milliseconds: 400));
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: appointments.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildAppointmentCard(appointments[index]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAssignAppointment() {
    final authService = Provider.of<AuthService>(context, listen: false);

    return StreamBuilder<List<UserModel>>(
      stream: authService.getAllProfilesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        // Filter out admins, show only regular users
        final users = (snapshot.data ?? [])
            .where((u) => u.role != 'admin')
            .where((u) {
              if (_searchQuery.isEmpty) return true;
              final nameMatch =
                  u.name.toLowerCase().contains(_searchQuery) ||
                  u.displayName.toLowerCase().contains(_searchQuery);
              final emailMatch = u.email.toLowerCase().contains(_searchQuery);
              final phoneMatch = u.phone.toLowerCase().contains(_searchQuery);
              return nameMatch || emailMatch || phoneMatch;
            })
            .toList();

        if (users.isEmpty) {
          return const EmptyState(
            icon: Icons.people_outline_rounded,
            title: 'No users to assign to',
            message: 'Users created by sign-up or WhatsApp will show here.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          itemCount: users.length,
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildUserCard(users[index]),
          ),
        );
      },
    );
  }

  Widget _buildUserCard(UserModel user) {
    final initial = user.name.isNotEmpty ? user.name[0].toUpperCase() : '?';
    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primarySoft,
                  border: Border.all(color: AppColors.primary.withAlpha(60)),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name.isNotEmpty ? user.name : user.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (user.email.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          user.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppStyles.bodySmall,
                        ),
                      ),
                    if (user.phone.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(user.phone, style: AppStyles.bodySmall),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showAssignmentDialog(user),
              icon: const Icon(
                Icons.add_task_rounded,
                size: 18,
                color: Colors.white,
              ),
              label: const Text(
                'Assign appointment',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAssignmentDialog(UserModel user) {
    final procedureService = ProcedureService();
    final locationService = ClinicLocationService();
    String? selectedProcedureId;
    String? selectedProcedureName;
    final dateController = TextEditingController();
    final timeController = TextEditingController();
    final notesController = TextEditingController();
    final visitNumberController = TextEditingController();
    final sessionNumberController = TextEditingController();
    String? selectedLocation;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Assign Appointment'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'For: ${user.name}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Procedure selection
                  StreamBuilder<List<ProcedureModel>>(
                    stream: procedureService.getAllProceduresStream(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final procedures = snapshot.data ?? [];
                      return DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Select Procedure',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: procedures.map((proc) {
                          return DropdownMenuItem<String>(
                            value: proc.id,
                            onTap: () => selectedProcedureName =
                                proc.title.isNotEmpty ? proc.title : proc.name,
                            child: Text(
                              proc.title.isNotEmpty ? proc.title : proc.name,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) => selectedProcedureId = value,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  // Date picker
                  TextField(
                    controller: dateController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Select Date',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      suffixIcon: const Icon(Icons.calendar_today),
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 90)),
                      );
                      if (date != null) {
                        dateController.text =
                            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  // Time picker
                  TextField(
                    controller: timeController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Select Time',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      suffixIcon: const Icon(Icons.access_time),
                    ),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (time != null) {
                        timeController.text =
                            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  // Notes
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Notes (optional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Visit Number
                  SizedBox(
                    width: double.infinity,
                    child: TextField(
                      controller: visitNumberController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Visit Number',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Session Number
                  TextField(
                    controller: sessionNumberController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Session Number',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Clinic Location Dropdown
                  FutureBuilder<List<ClinicLocationModel>>(
                    future: locationService.getLocations(activeOnly: true),
                    builder: (context, snapshot) {
                      final locations = snapshot.data ?? [];
                      return DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Clinic Location',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: locations
                            .map(
                              (loc) => DropdownMenuItem(
                                value: loc.displayLabel,
                                child: Text(
                                  loc.displayLabel,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setDialogState(() => selectedLocation = val),
                      );
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (selectedProcedureId == null ||
                      dateController.text.isEmpty ||
                      timeController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please fill all required fields'),
                      ),
                    );
                    return;
                  }

                  final error = await _appointmentService.assignAppointment(
                    userId: user.uid,
                    userName: user.displayName.isNotEmpty
                        ? user.displayName
                        : user.name,
                    procedureId: selectedProcedureId!,
                    procedureName: selectedProcedureName ?? 'Procedure',
                    appointmentDate: dateController.text,
                    appointmentTime: timeController.text,
                    notes: notesController.text,
                    visitNumber: int.tryParse(visitNumberController.text) ?? 1,
                    sessionNumber:
                        int.tryParse(sessionNumberController.text) ?? 1,
                    clinicLocation: selectedLocation ?? '',
                  );

                  if (!context.mounted) return;
                  Navigator.pop(context);

                  if (error != null) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $error')));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Appointment assigned successfully'),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: const Text('Assign'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAppointmentCard(AppointmentModel appointment) {
    return SoftCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              AppointmentDetailScreen(appointmentId: appointment.id),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
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
                    const SizedBox(height: 2),
                    Text(
                      appointment.userName.isNotEmpty
                          ? appointment.userName
                          : 'Unknown user',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(status: appointment.status),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _meta(Icons.calendar_today_rounded, appointment.appointmentDate),
              _meta(Icons.access_time_rounded, appointment.appointmentTime),
              _meta(
                Icons.location_on_outlined,
                appointment.clinicLocation.isNotEmpty
                    ? appointment.clinicLocation
                    : 'Not set',
              ),
              _meta(
                Icons.repeat_rounded,
                'S${appointment.sessionNumber} · V${appointment.visitNumber}',
              ),
            ],
          ),
          if (appointment.originalScheduledAt != null &&
              appointment.originalScheduledAt!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _meta(
                Icons.history_rounded,
                'Was: ${appointment.originalScheduledAt}',
              ),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _statusActionButton(
                  label: 'Complete',
                  icon: Icons.check_rounded,
                  color: AppColors.success,
                  onTap: () =>
                      _updateStatus(context, appointment.id, 'completed'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statusActionButton(
                  label: 'Missed',
                  icon: Icons.access_alarm_rounded,
                  color: AppColors.warning,
                  onTap: () => _updateStatus(context, appointment.id, 'missed'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statusActionButton(
                  label: 'Cancel',
                  icon: Icons.cancel_outlined,
                  color: AppColors.error,
                  onTap: () =>
                      _updateStatus(context, appointment.id, 'cancelled'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(text, style: AppStyles.bodySmall, overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _statusActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withAlpha(28),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withAlpha(60)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateStatus(
    BuildContext context,
    String appointmentId,
    String status,
  ) async {
    try {
      await _appointmentService.updateAppointmentStatus(
        appointmentId: appointmentId,
        status: status,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Appointment marked as $status')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating appointment: $e')),
        );
      }
    }
  }
}
