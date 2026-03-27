import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../constants/styles.dart';
import '../../models/procedure_model.dart';
import '../../services/appointment_service.dart';
import '../../services/auth_service.dart';
import '../../services/procedure_service.dart';

class BookAppointmentScreen extends StatefulWidget {
  final ProcedureModel? preSelectedProcedure;
  final String? targetUserId; // For admin to book for a specific user
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
  final TextEditingController _sessionNumberController = TextEditingController();
  String? _selectedLocation;
  bool _isLoading = false;
  List<ProcedureModel> _procedures = [];


  @override
  void initState() {
    super.initState();
    _selectedProcedure = widget.preSelectedProcedure;
    _fetchProcedures();
  }

  Future<void> _fetchProcedures() async {
    final procedures = await ProcedureService().getAllProcedures();
    setState(() {
      _procedures = procedures;
      if (_selectedProcedure == null && _procedures.isNotEmpty) {
        _selectedProcedure = _procedures.first;
      }
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _bookAppointment() async {
    if (_selectedProcedure == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a procedure')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      final currentUser = authService.currentUser;

      // Determine who the appointment is for
      String userId;

      if (widget.targetUserId != null) {
        // Admin booking for a user
        userId = widget.targetUserId!;
      } else {
        // User booking for themselves
        if (currentUser == null) {
          throw Exception('User not logged in');
        }
        userId = currentUser.uid;
      }

      // Format date and time as strings
      final appointmentDate =
          "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
      final appointmentTime =
          "${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}";

      // Book the appointment
      String? result;
      if (widget.targetUserId != null) {
        result = await _appointmentService.assignAppointment(
          userId: userId,
          userName: widget.targetUserName ?? '',
          procedureId: _selectedProcedure!.id,
          procedureName: _selectedProcedure!.name,
          appointmentDate: appointmentDate,
          appointmentTime: appointmentTime,
          notes: _notesController.text.trim(),
          visitNumber: int.tryParse(_visitNumberController.text) ?? 1,
          sessionNumber: int.tryParse(_sessionNumberController.text) ?? 1,
          clinicLocation: _selectedLocation ?? '',
        );
      } else {
        result = await _appointmentService.bookAppointment(
          procedureId: _selectedProcedure!.id,
          procedureName: _selectedProcedure!.name,
          appointmentDate: appointmentDate,
          appointmentTime: appointmentTime,
          notes: _notesController.text.trim(),
          userName: currentUser?.displayName ?? '',
          visitNumber: int.tryParse(_visitNumberController.text) ?? 1,
          sessionNumber: int.tryParse(_sessionNumberController.text) ?? 1,
          clinicLocation: _selectedLocation ?? '',
        );
      }


      if (result != null) {
        throw Exception(result);
      }

      if (mounted) {
        // If Admin booked, show specific message
        final successMessage = widget.targetUserId != null
            ? 'Appointment assigned to ${widget.targetUserName} successfully!'
            : 'Appointment booked successfully!';

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(successMessage)));

        // Pop twice to go back to dashboard/home where the appointment will appear
        // Or navigate to appointments list to see the booked appointment
        Navigator.pop(context); // Close the booking screen

        // Optionally navigate to the appointments list to see the new appointment
        // Uncomment the next line if you want to navigate to appointments after booking
        // Navigator.pushNamed(context, AppRoutes.appointments);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error booking appointment: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          "Book Appointment",
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Select Procedure",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: AppStyles.inputDecoration("").copyWith(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<ProcedureModel>(
                  value: _selectedProcedure,
                  isExpanded: true,
                  hint: const Text("Choose a procedure"),
                  items: _procedures.map((ProcedureModel procedure) {
                    return DropdownMenuItem<ProcedureModel>(
                      value: procedure,
                      child: Text(procedure.name),
                    );
                  }).toList(),
                  onChanged: (ProcedureModel? newValue) {
                    setState(() {
                      _selectedProcedure = newValue;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Select Date & Time",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectDate(context),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: AppStyles.cardDecoration,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}",
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectTime(context),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: AppStyles.cardDecoration,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _selectedTime.format(context),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              "Additional Notes",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: AppStyles.inputDecoration(
                "Any special requests or allergies?",
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Visit & Session Info",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _visitNumberController,
                    keyboardType: TextInputType.number,
                    decoration: AppStyles.inputDecoration("Visit #"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _sessionNumberController,
                    keyboardType: TextInputType.number,
                    decoration: AppStyles.inputDecoration("Session #"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              "Clinic Location",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: AppStyles.inputDecoration("Select Location"),
              items: [
                'Lahore, Pakistan',
                'Karachi, Pakistan',
                'Islamabad, Pakistan',
                'Dubai, UAE'
              ].map((loc) => DropdownMenuItem(value: loc, child: Text(loc))).toList(),
              onChanged: (val) => setState(() => _selectedLocation = val),
            ),

            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _bookAppointment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Confirm Booking",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
