import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import 'dashboard.dart';
import '../procedures/procedures_list_screen.dart';
import '../chat/unified_chat_screen.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0; // Index for BottomNavigationBar (0-4)

  Future<void> _launchShopUrl() async {
    final Uri url = Uri.parse('https://5kassi.com/skinbyfizza/shop/');
    if (!await launchUrl(url, mode: LaunchMode.inAppWebView)) {
      throw Exception('Could not launch $url');
    }
  }

  void _onTabTapped(int index) {
    if (index == 2) {
      // Shop link
      _launchShopUrl();
      // Do not update state/index for external link
    } else {
      setState(() {
        _navIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    final userId = authService.currentUserId;

    // Define all screens once
    final List<Widget> pages = [
      const Dashboard(),
      const ProceduresListScreen(),
      const SizedBox(), // Placeholder for Shop link
      const UnifiedChatScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _navIndex, children: pages),
      bottomNavigationBar: StreamBuilder<int>(
        stream: userId != null
            ? ChatService().getUserUnreadCountStream(userId)
            : Stream.value(0),
        builder: (context, snapshot) {
          final unreadCount = snapshot.data ?? 0;
          return BottomNavBar(
            currentIndex: _navIndex,
            onTap: _onTabTapped,
            unreadCount: unreadCount,
            isAdmin: false, // User mode
          );
        },
      ),
    );
  }
}
