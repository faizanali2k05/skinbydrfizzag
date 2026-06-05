import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../constants/styles.dart';
import '../../models/appointment_model.dart';
import '../../services/appointment_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/soft_card.dart';

class RescheduleScreen extends StatefulWidget {
  final String appointmentId;
  const RescheduleScreen({super.key, required this.appointmentId});

  @override
  State<RescheduleScreen> createState() => _RescheduleScreenState();
}

class _RescheduleScreenState extends State<RescheduleScreen> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  AppointmentModel? _appointment;
  bool _isLoading = true;
  bool _isSaving = false;
  final AppointmentService _appointmentService = AppointmentService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final appointment =
          await _appointmentService.getAppointment(widget.appointmentId);
      if (!mounted) return;
      setState(() {
        _appointment = appointment;
        if (appointment != null) {
          try {
            final d = appointment.appointmentDate.split('-');
            if (d.length == 3) {
              _selectedDate = DateTime(
                int.parse(d[0]),
                int.parse(d[1]),
                int.parse(d[2]),
              );
            }
            final t = appointment.appointmentTime.split(':');
            if (t.length >= 2) {
              _selectedTime = TimeOfDay(
                hour: int.parse(t[0]),
                minute: int.parse(t[1]),
              );
            }
          } catch (_) {}
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading appointment: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 10, minute: 0),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _save() async {
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both date and time')),
      );
      return;
    }
    setState(() => _isSaving = true);

    final newDate =
        "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}";
    final newTime =
        "${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}";

    final err = await _appointmentService.rescheduleAppointment(
      widget.appointmentId,
      newDate,
      newTime,
      _appointment?.scheduledAt,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $err'), backgroundColor: AppColors.error),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Appointment rescheduled successfully.'),
        backgroundColor: AppColors.success,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _appointment == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Reschedule'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current appointment', style: AppStyles.h3),
                    const SizedBox(height: 10),
                    _row(
                      Icons.medical_services_rounded,
                      _appointment!.procedureName,
                    ),
                    const SizedBox(height: 6),
                    _row(
                      Icons.calendar_today_rounded,
                      _appointment!.appointmentDate,
                    ),
                    const SizedBox(height: 6),
                    _row(
                      Icons.access_time_rounded,
                      _appointment!.appointmentTime,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text('New date & time', style: AppStyles.h3),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _picker(
                    icon: Icons.calendar_today_rounded,
                    label: _selectedDate != null
                        ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                        : 'Select date',
                    onTap: _pickDate,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _picker(
                    icon: Icons.access_time_rounded,
                    label: _selectedTime != null
                        ? _selectedTime!.format(context)
                        : 'Select time',
                    onTap: _pickTime,
                  )),
                ],
              ),
              const SizedBox(height: 32),
              CustomButton(
                text: 'Confirm reschedule',
                onPressed: _save,
                isLoading: _isSaving,
                icon: Icons.check_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
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
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
