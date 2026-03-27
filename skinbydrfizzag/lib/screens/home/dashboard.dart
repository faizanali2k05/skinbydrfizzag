import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/colors.dart';
import '../../constants/strings.dart';
import '../../constants/styles.dart';
import '../../routes/app_routes.dart';
import '../../models/appointment_model.dart';
import '../../models/procedure_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/notification_service.dart';
import '../../services/appointment_service.dart';
import '../../services/procedure_service.dart';
import '../chat/unified_chat_screen.dart';
import '../appointments/appointment_detail_screen.dart';
import '../appointments/reschedule_screen.dart';
import '../procedures/procedure_detail_screen.dart';
import 'notifications_screen.dart';
import '../../constants/currency.dart';
import 'dart:async';
import '../../models/notification_model.dart';
import '../../services/notification_manager.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  StreamSubscription<List<NotificationModel>>? _notificationSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final authService = Provider.of<AuthService>(context, listen: false);
        final notificationService = Provider.of<NotificationService>(
          context,
          listen: false,
        );
        final userId = authService.currentUserId;
        if (userId != null) {
          notificationService.startListeningForAppointments(userId);
          notificationService.startListeningForChat(userId);
          NotificationManager.saveTokenToSupabase(userId);

          // Local notifications for new notifications rows
          final sessionStartTime = DateTime.now();
          _notificationSub?.cancel();
          _notificationSub = notificationService
              .getUserNotificationsStream(userId)
              .listen((list) {
            if (list.isEmpty) return;
            // Only show if the most recent notification is new and occurred after we started listening
            final latest = list.first;
            if (latest.createdAt != null &&
                latest.createdAt!.isAfter(sessionStartTime) &&
                !latest.isRead) {
              NotificationManager.showLocalNotification(
                title: latest.title,
                body: latest.message,
              );
            }
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _notificationSub?.cancel();
    super.dispose();
  }

  Stream<int> _getCombinedUnreadCountStream(
    BuildContext context,
    String userId,
  ) {
    final notificationService = Provider.of<NotificationService>(
      context,
      listen: false,
    );
    final chatService = Provider.of<ChatService>(context, listen: false);

    return Rx.combineLatest2(
      notificationService.getUnreadCountStream(userId),
      chatService.getUserUnreadCountStream(userId),
      (int notificationCount, int chatCount) => notificationCount + chatCount,
    );
  }

  Future<void> _launchShopUrl() async {
    final Uri url = Uri.parse('https://5kassi.com/skinbyfizza/shop/');
    if (!await launchUrl(url, mode: LaunchMode.inAppWebView)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      endDrawer: _buildNotificationDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          key: const PageStorageKey('dashboard_scroll'),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDynamicHeader(context),
              const SizedBox(height: 24),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  _buildQuickAccessCard(
                    context,
                    title: AppStrings.procedures,
                    subtitle: AppStrings.bookNow,
                    icon: Icons.calendar_today,
                    color: AppColors.cardProcedures,
                    iconColor: AppColors.warning,
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.procedures),
                  ),
                  _buildQuickAccessCard(
                    context,
                    title: AppStrings.shop,
                    subtitle: AppStrings.browse,
                    icon: Icons.shopping_bag_outlined,
                    color: AppColors.cardShop,
                    iconColor: AppColors.accent,
                    onTap: _launchShopUrl,
                  ),
                  _buildQuickAccessCard(
                    context,
                    title: "My Appointments",
                    subtitle: "View upcoming visits",
                    icon: Icons.event_available,
                    color: AppColors.cardMedical,
                    iconColor: Colors.blue,
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.appointments),
                  ),
                  _buildDoctorDeskCard(context),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    AppStrings.upcomingAppointments,
                    style: AppStyles.h3,
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.appointments),
                    child: Text(
                      AppStrings.seeAll,
                      style: AppStyles.bodyMedium.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              _buildUpcomingAppointmentCard(context),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Featured Procedures",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.procedures),
                    child: Text(
                      AppStrings.seeAll,
                      style: AppStyles.bodyMedium.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 180,
                child: StreamBuilder<List<ProcedureModel>>(
                  stream: Provider.of<ProcedureService>(
                    context,
                    listen: false,
                  ).getAllProceduresStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                        child: Text("No procedures available yet."),
                      );
                    }
                    final procedures = snapshot.data!;
                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: procedures.length,
                      itemBuilder: (context, index) {
                        final procedure = procedures[index];
                        return _buildFeaturedProcedureCard(procedure);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
              _buildAboutUsSection(context),
              const SizedBox(height: 40),

            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDoctorDeskCard(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final chatService = Provider.of<ChatService>(context, listen: false);
    final userId = authService.currentUserId;

    return StreamBuilder<int>(
      stream: userId != null
          ? chatService.getUserUnreadCountStream(userId)
          : Stream.value(0),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            _buildQuickAccessCard(
              context,
              title: AppStrings.medicalTourism,
              subtitle: "Consult with doctor",
              icon: Icons.medical_services_outlined,
              color: AppColors.cardMedical,
              iconColor: AppColors.secondary,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UnifiedChatScreen(),
                  ),
                );
              },
            ),
            if (unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDynamicHeader(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUserId;

    if (userId == null) return const SizedBox();

    return FutureBuilder<UserModel?>(
      future: authService.getCurrentUserDocument(),
      builder: (context, snapshot) {
        String displayName = "User";
        if (snapshot.hasData && snapshot.data != null) {
          displayName = snapshot.data!.name;
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(AppStrings.hello, style: AppStyles.bodyLarge),
                const SizedBox(height: 4),
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, size: 28),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NotificationsScreen(),
                      ),
                    );
                  },
                ),
                StreamBuilder<int>(
                  stream: _getCombinedUnreadCountStream(context, userId),
                  builder: (context, snapshot) {
                    final unreadCount = snapshot.data ?? 0;
                    if (unreadCount > 0) {
                      return Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            unreadCount > 9 ? '9+' : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }
                    return const SizedBox();
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildUpcomingAppointmentCard(BuildContext context) {
    final appointmentService = Provider.of<AppointmentService>(
      context,
      listen: false,
    );
    return StreamBuilder<List<AppointmentModel>>(
      stream: appointmentService.getUserAppointmentsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _noAppointmentsCard();
        }

        final upcomingAppointment = snapshot.data!.firstWhere((appointment) {
          try {
            final dateParts = appointment.appointmentDate.split('-');
            final timeParts = appointment.appointmentTime.split(':');
            if (dateParts.length == 3 && timeParts.length >= 2) {
              final appointmentDateTime = DateTime(
                int.parse(dateParts[0]),
                int.parse(dateParts[1]),
                int.parse(dateParts[2]),
                int.parse(timeParts[0]),
                int.parse(timeParts[1]),
              );
              return (appointment.status == 'booked' ||
                      appointment.status == 'confirmed') &&
                  appointmentDateTime.isAfter(DateTime.now());
            }
          } catch (e) {
            // Handle parsing error
          }
          return false;
        }, orElse: () => AppointmentModel.empty());

        if (upcomingAppointment.id.isEmpty) {
          return _noAppointmentsCard();
        }

        DateTime appointmentDateTime = DateTime.now();
        try {
          final dateParts = upcomingAppointment.appointmentDate.split('-');
          final timeParts = upcomingAppointment.appointmentTime.split(':');
          if (dateParts.length == 3 && timeParts.length >= 2) {
            appointmentDateTime = DateTime(
              int.parse(dateParts[0]),
              int.parse(dateParts[1]),
              int.parse(dateParts[2]),
              int.parse(timeParts[0]),
              int.parse(timeParts[1]),
            );
          }
        } catch (e) {
          // Handle parsing error
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: AppStyles.cardDecoration,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.cardProcedures,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              appointmentDateTime.day.toString(),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _getMonth(appointmentDateTime),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            upcomingAppointment.procedureName,
                            style: AppStyles.h3.copyWith(fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatTime(appointmentDateTime),
                                style: AppStyles.bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                "Main Clinic",
                                style: AppStyles.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(upcomingAppointment.status),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      upcomingAppointment.status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RescheduleScreen(
                              appointmentId: upcomingAppointment.id,
                            ),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        side: BorderSide.none,
                        backgroundColor: Colors.grey[100],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text("Reschedule"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AppointmentDetailScreen(
                              appointmentId: upcomingAppointment.id,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        "View Details",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _noAppointmentsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: AppStyles.cardDecoration,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            size: 48,
            color: Colors.grey,
          ),
          const SizedBox(height: 12),
          const Text(
            "No upcoming appointments.",
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.bookAppointment),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              "Book Appointment",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationDrawer() {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 50),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text("Notifications", style: AppStyles.h2),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildNotificationItem(
                    "Special Offer",
                    "Get 20% off on HydraFacial this week!",
                    "5 hours ago",
                    Icons.local_offer,
                    Colors.orange,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem(
    String title,
    String message,
    String time,
    IconData icon,
    Color color,
  ) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.1),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(message, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          Text(time, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildQuickAccessCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: AppStyles.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedProcedureCard(ProcedureModel procedure) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProcedureDetailScreen(procedure: procedure),
          ),
        );
      },
      child: Container(
        width: 250,
        margin: const EdgeInsets.only(right: 16),
        decoration: AppStyles.cardDecoration,
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: Colors.grey[200],
                child: (procedure.imageUrl.isNotEmpty)
                    ? Image.network(
                        procedure.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.broken_image,
                              size: 40,
                              color: Colors.grey,
                            ),
                      )
                    : const Icon(
                        Icons.medical_services,
                        size: 40,
                        color: Colors.grey,
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PROCEDURE',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    procedure.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    CurrencyConstants.formatCurrency(
                      procedure.price,
                      currencyCode: 'AED',
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutUsSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(20),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.info_outline, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              const Text(
                "About Us",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            "Skin by Dr. Fizza is a premier aesthetic clinic dedicated to enhancing your natural beauty. Led by Dr. Fizza, our team provides expert care in skin rejuvenation, anti-aging, and therapeutic treatments using state-of-the-art technology.",
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.location_on, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "Main Clinic, DHA Phase 5, Lahore",
                  style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.aboutUs),

            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text("Learn More"),
          ),
        ],
      ),
    );
  }

  String _getMonth(DateTime date) {
    const months = [
      "JAN",
      "FEB",
      "MAR",
      "APR",
      "MAY",
      "JUN",
      "JUL",
      "AUG",
      "SEP",
      "OCT",
      "NOV",
      "DEC",
    ];
    return months[date.month - 1];
  }

  String _formatTime(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return "$hour:$minute $period";
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'cancelled':
        return AppColors.error;
      case 'completed':
        return AppColors.primary;
      case 'booked':
        return AppColors.primary;
      case 'missed':
        return AppColors.error;
      default:
        return Colors.grey;
    }
  }
}

