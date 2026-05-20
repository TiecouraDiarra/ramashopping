import 'package:flutter/material.dart';

class BottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTap;

  const BottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onTap,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard),
          label: 'Tableau',
        ),
        NavigationDestination(
          icon: Icon(Icons.shopping_cart),
          label: 'Commandes',
        ),
        NavigationDestination(
          icon: Icon(Icons.account_balance_wallet),
          label: 'Trésorerie',
        ),
        NavigationDestination(
          icon: Icon(Icons.people),
          label: 'Clients',
        ),
        NavigationDestination(
          icon: Icon(Icons.bar_chart),
          label: 'Rapports',
        ),
      ],
    );
  }
}