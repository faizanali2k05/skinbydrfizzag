import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../constants/styles.dart';
import '../../models/clinic_location_model.dart';
import '../../models/procedure_model.dart';
import '../../services/appointment_service.dart';
import '../../services/auth_service.dart';
import '../../services/clinic_location_service.dart';
import '../../services/procedure_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/soft_card.dart';

class BookAppointmentScreen extends StatefulWidget {
  final ProcedureModel? preSelectedProcedure;
  final String? targetUserId;
  final String? targetUserName;

  const BookAppointmentScreen({
    super.key,
    this.preSelectedProcedure,
    this.targetUserId,
    this.targetUserName,
  });

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 10, minute: 0);
  ProcedureModel? _selectedProcedure;
  final AppointmentService _appointmentService = AppointmentService();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _visitNumberController = TextEditingController();
  final TextEditingController _sessionNumberController =
      TextEditingController();
  String? _selectedLocation;
  bool _isLoading = false;
  List<ProcedureModel> _procedures = [];
  List<ClinicLocationModel> _locations = [];

  @override
  void initState() {
    super.initState();
    _selectedProcedure = widget.preSelectedProcedure;
    _fetchProcedures();
    _fetchLocations();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _visitNumberController.dispose();
    _sessionNumberController.dispose();
    super.dispose();
  }

  Future<void> _fetchProcedures() async {
    final list = await ProcedureService().getAllProcedures();
    if (!mounted) return;
    setState(() {
      _procedures = list;
      if (_selectedProcedure == null && list.isNotEmpty) {
        _selectedProcedure = list.first;
      }
    });
  }

  Future<void> _fetchLocations() async {
    final list = await ClinicLocationService().getLocations(activeOnly: true);
    if (!mounted) return;
    setState(() {
      _locations = list;
      if (_selectedLocation == null && list.isNotEmpty) {
        _selectedLocation = list.first.displayLabel;
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _book() async {
    if (_selectedProcedure == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a procedure')),
      );
      return;
    }
    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      final currentUser = authService.currentUser;
      final userId = widget.targetUserId ?? currentUser?.uid;
      if (userId == null) throw Exception('User not signed in.');

      final date =
          "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
      final time =
          "${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}";

      final result = widget.targetUserId != null
          ? await _appointmentService.assignAppointment(
              userId: userId,
              userName: widget.targetUserName ?? '',
              procedureId: _selectedProcedure!.id,
              procedureName: _selectedProcedure!.name,
              appointmentDate: date,
              appointmentTime: time,
              notes: _notesController.text.trim(),
              visitNumber: int.tryParse(_visitNumberController.text) ?? 1,
              sessionNumber: int.tryParse(_sessionNumberController.text) ?? 1,
              clinicLocation: _selectedLocation ?? '',
            )
          : await _appointmentService.bookAppointment(
              procedureId: _selectedProcedure!.id,
              procedureName: _selectedProcedure!.name,
              appointmentDate: date,
              appointmentTime: time,
              notes: _notesController.text.trim(),
              userName: currentUser?.displayName ?? currentUser?.name ?? '',
              visitNumber: int.tryParse(_visitNumberController.text) ?? 1,
              sessionNumber: int.tryParse(_sessionNumberController.text) ?? 1,
              clinicLocation: _selectedLocation ?? '',
            );

      if (result != null) throw Exception(result);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.targetUserId != null
                ? 'Appointment assigned to ${widget.targetUserName} successfully.'
                : 'Appointment booked successfully.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Book Appointment'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.targetUserName != null)
                SoftCard(
                  color: AppColors.primarySoft,
                  border: Border.all(color: AppColors.primary.withAlpha(80)),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person_pin_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Booking for ${widget.targetUserName}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (widget.targetUserName != null) const SizedBox(height: 16),
              Text('Procedure', style: AppStyles.h3),
              const SizedBox(height: 10),
              SoftCard(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<ProcedureModel>(
                    value: _selectedProcedure,
                    isExpanded: true,
                    hint: const Text('Choose a procedure'),
                    items: _procedures
                        .map(
                          (p) =>
                              DropdownMenuItem(value: p, child: Text(p.name)),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedProcedure = v),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text('Date & time', style: AppStyles.h3),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _picker(
                      icon: Icons.calendar_today_rounded,
                      label:
                          '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                      onTap: _pickDate,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _picker(
                      icon: Icons.access_time_rounded,
                      label: _selectedTime.format(context),
                      onTap: _pickTime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text('Notes', style: AppStyles.h3),
              const SizedBox(height: 10),
              TextField(
                controller: _notesController,
                maxLines: 4,
                decoration: AppStyles.inputDecoration(
                  'Any special requests or allergies?',
                ),
              ),
              const SizedBox(height: 18),
              Text('Visit & session', style: AppStyles.h3),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _visitNumberController,
                      keyboardType: TextInputType.number,
                      decoration: AppStyles.inputDecoration('Visit #'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _sessionNumberController,
                      keyboardType: TextInputType.number,
                      decoration: AppStyles.inputDecoration('Session #'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text('Clinic location', style: AppStyles.h3),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _selectedLocation,
                decoration: AppStyles.inputDecoration('Select location'),
                items: _locations
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
                onChanged: (v) => setState(() => _selectedLocation = v),
              ),
              const SizedBox(height: 32),
              CustomButton(
                text: 'Confirm booking',
                onPressed: _book,
                isLoading: _isLoading,
                icon: Icons.event_available_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _picker({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
