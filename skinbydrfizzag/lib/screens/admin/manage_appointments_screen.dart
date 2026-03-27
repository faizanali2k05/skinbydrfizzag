import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../constants/styles.dart';
import '../../models/appointment_model.dart';

import '../../models/user_model.dart';
import '../../models/procedure_model.dart';
import '../../services/appointment_service.dart';
import '../../services/auth_service.dart';
import '../../services/procedure_service.dart';
import 'package:provider/provider.dart';

class ManageAppointmentsScreen extends StatefulWidget {
  const ManageAppointmentsScreen({super.key});

  @override
  State<ManageAppointmentsScreen> createState() => _ManageAppointmentsScreenState();
}

class _ManageAppointmentsScreenState extends State<ManageAppointmentsScreen> {
  final AppointmentService _appointmentService = AppointmentService();
  int _selectedTabIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Manage Appointments', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              decoration: AppStyles.inputDecoration(
                "Search by procedure or user...",
                prefixIcon: Icons.search,
              ).copyWith(
                contentPadding: const EdgeInsets.all(0),
              ),
            ),
          ),
        ),
      ),

      body: Column(
        children: [
          // Tab buttons
          Container(
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTabIndex = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _selectedTabIndex == 0 ? AppColors.primary : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'All Appointments',
                          style: TextStyle(
                            color: _selectedTabIndex == 0 ? AppColors.primary : Colors.grey,
                            fontWeight: _selectedTabIndex == 0 ? FontWeight.bold : FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTabIndex = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _selectedTabIndex == 1 ? AppColors.primary : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Assign New',
                          style: TextStyle(
                            color: _selectedTabIndex == 1 ? AppColors.primary : Colors.grey,
                            fontWeight: _selectedTabIndex == 1 ? FontWeight.bold : FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Tab content
          Expanded(
            child: _selectedTabIndex == 0 ? _buildAppointmentsList() : _buildAssignAppointment(),
          ),
        ],
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
          return const Center(
            child: Text(
              'No appointments found',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
          );
        }

        final allAppointments = snapshot.data ?? [];
        final appointments = allAppointments.where((a) {
          final procedureMatch = a.procedureName.toLowerCase().contains(_searchQuery);
          final userMatch = a.userName.toLowerCase().contains(_searchQuery);
          return procedureMatch || userMatch;
        }).toList();

        return RefreshIndicator(
          onRefresh: () async {
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
        final users = (snapshot.data ?? []).where((u) => u.role != 'admin').toList();

        if (users.isEmpty) {
          return const Center(child: Text('No users available'));
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
    );
  }

  Widget _buildUserCard(UserModel user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withAlpha(26),
          child: Text(
            (user.name.isNotEmpty ? user.name[0] : '?').toUpperCase(),
            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          user.name.isNotEmpty ? user.name : user.email,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(user.email, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: ElevatedButton.icon(
          onPressed: () => _showAssignmentDialog(user),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Assign'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
      ),
    );
  }

  void _showAssignmentDialog(UserModel user) {
    final procedureService = ProcedureService();
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
                  Text('For: ${user.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                        decoration: InputDecoration(
                          labelText: 'Select Procedure',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: procedures.map((proc) {
                          return DropdownMenuItem<String>(
                            value: proc.id,
                            onTap: () => selectedProcedureName = proc.title.isNotEmpty ? proc.title : proc.name,
                            child: Text(proc.title.isNotEmpty ? proc.title : proc.name),
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                        dateController.text = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      suffixIcon: const Icon(Icons.access_time),
                    ),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (time != null) {
                        timeController.text = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Visit Number
                  TextField(
                    controller: visitNumberController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Visit Number',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Session Number
                  TextField(
                    controller: sessionNumberController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Session Number',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Clinic Location Dropdown
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Clinic Location',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: [
                      'Lahore, Pakistan',
                      'Karachi, Pakistan',
                      'Islamabad, Pakistan',
                      'Dubai, UAE'
                    ].map((loc) => DropdownMenuItem(value: loc, child: Text(loc))).toList(),
                    onChanged: (val) => setDialogState(() => selectedLocation = val),
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
                  if (selectedProcedureId == null || dateController.text.isEmpty || timeController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please fill all required fields')),
                    );
                    return;
                  }

                  final error = await _appointmentService.assignAppointment(
                    userId: user.uid,
                    userName: user.displayName.isNotEmpty ? user.displayName : user.name,
                    procedureId: selectedProcedureId!,
                    procedureName: selectedProcedureName ?? 'Procedure',
                    appointmentDate: dateController.text,
                    appointmentTime: timeController.text,
                    notes: notesController.text,
                    visitNumber: int.tryParse(visitNumberController.text) ?? 1,
                    sessionNumber: int.tryParse(sessionNumberController.text) ?? 1,
                    clinicLocation: selectedLocation ?? '',
                  );

                  if (!context.mounted) return;
                  Navigator.pop(context);

                  if (error != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $error')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Appointment assigned successfully')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('Assign'),
              ),
            ],
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            _buildInfoRow(Icons.person, 'User: ${appointment.userName.isNotEmpty ? appointment.userName : appointment.userId}'),
            const SizedBox(height: 4),
            _buildInfoRow(Icons.calendar_today, 'Date: ${appointment.appointmentDate}'),
            const SizedBox(height: 4),
            _buildInfoRow(Icons.access_time, 'Time: ${appointment.appointmentTime}'),
            const SizedBox(height: 4),
            _buildInfoRow(Icons.location_on, 'Location: ${appointment.clinicLocation.isNotEmpty ? appointment.clinicLocation : "Not specified"}'),

            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _updateStatus(context, appointment.id, 'completed'),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Complete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade100,
                      foregroundColor: Colors.green.shade800,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _updateStatus(context, appointment.id, 'missed'),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Missed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade100,
                      foregroundColor: Colors.orange.shade800,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _updateStatus(context, appointment.id, 'cancelled'),
                    icon: const Icon(Icons.cancel, size: 18),
                    label: const Text('Cancel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade100,
                      foregroundColor: Colors.red.shade800,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
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
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: AppColors.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
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

  Future<void> _updateStatus(BuildContext context, String appointmentId, String status) async {
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
