import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/bottom_nav_bar.dart';
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
    bool launched = false;
    try {
      launched = await launchUrl(url, mode: LaunchMode.inAppWebView);
    } catch (_) {
      launched = false;
    }
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the shop. Please try again.')),
      );
    }
  }

  void _onTabTapped(int index) {
    if (index == 2) {
      // Shop link — external, so don't change the selected tab.
      _launchShopUrl();
    } else {
      setState(() {
        _navIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
      bottomNavigationBar: BottomNavBar(
        currentIndex: _navIndex,
        onTap: _onTabTapped,
        unreadCount: 0,
        isAdmin: false,
      ),
    );
  }
}
