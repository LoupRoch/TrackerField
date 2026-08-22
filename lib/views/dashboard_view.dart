import 'package:flutter/material.dart';

import 'athletes_view.dart';
import 'historique_seances_view.dart';
import 'live_session_view.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  int _currentIndex = 0;
  final _historiqueKey = GlobalKey<HistoriqueSeancesViewState>();

  late final List<Widget> _pages = [
    const AthletesView(),
    const LiveSessionView(),
    HistoriqueSeancesView(key: _historiqueKey),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (index == 2) {
            _historiqueKey.currentState?.reload();
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Athlètes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.timer),
            label: 'Séances',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Historique',
          ),
        ],
      ),
    );
  }
}
