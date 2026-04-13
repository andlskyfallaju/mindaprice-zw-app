import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'home_screen.dart';
import 'chat_list_screen.dart';
import 'advisory_screen.dart';
import 'settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;

  const MainNavigationScreen({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;

  final List<Widget> _pages = const [
    HomeScreen(),
    ChatListScreen(),
    AdvisoryScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    
    // Check for arguments from notification navigation if initialIndex is default
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is int) {
        setState(() {
          _currentIndex = args;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: currentUser == null
          ? null
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('conversations')
                  .where('participants', arrayContains: currentUser.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                int unreadChats = 0;

                if (snapshot.hasData) {
                  for (final doc in snapshot.data!.docs) {
                    final data = Map<String, dynamic>.from(doc.data() as Map);
                    final unreadCounts =
                      Map<String, dynamic>.from(data['unreadCounts'] ?? {});
                    final count = (unreadCounts[currentUser.uid] ?? 0) as int;
                    if (count > 0) unreadChats++;
                  }
                }

                return NavigationBar(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  destinations: [
                    const NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: 'Home',
                    ),
                    NavigationDestination(
                      icon: unreadChats > 0
                          ? Badge(
                              label: Text(unreadChats.toString()),
                              child: const Icon(Icons.chat_bubble_outline),
                            )
                          : const Icon(Icons.chat_bubble_outline),
                      selectedIcon: unreadChats > 0
                          ? Badge(
                              label: Text(unreadChats.toString()),
                              child: const Icon(Icons.chat_bubble),
                            )
                          : const Icon(Icons.chat_bubble),
                      label: 'Messenger',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.eco_outlined),
                      selectedIcon: Icon(Icons.eco),
                      label: 'Advisory',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings),
                      label: 'Settings',
                    ),
                  ],
                );
              },
            ),
    );
  }
}