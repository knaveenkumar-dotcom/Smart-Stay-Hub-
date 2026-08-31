import 'package:flutter/material.dart';
import '../../config.dart';
import '../setup_screen.dart';
import 'warden_dashboard_tab.dart';
import 'warden_attendance_tab.dart';
import 'warden_visitors_tab.dart';
import 'warden_maintenance_tab.dart';
import 'warden_fees_tab.dart';
import 'warden_rooms_tab.dart';
import 'warden_sensors_tab.dart';

class WardenShell extends StatefulWidget {
  const WardenShell({super.key});

  @override
  State<WardenShell> createState() => _WardenShellState();
}

class _WardenShellState extends State<WardenShell> {
  int _index = 0;

  final _tabs = const [
    WardenDashboardTab(),
    WardenAttendanceTab(),
    WardenVisitorsTab(),
    WardenMaintenanceTab(),
    WardenFeesTab(),
    WardenRoomsTab(),
    WardenSensorsTab(),
  ];

  final _titles = const ['Overview', 'Attendance', 'Visitors', 'Maintenance', 'Fees', 'Rooms', 'Sensors'];
  final _icons = const [
    Icons.dashboard_outlined,
    Icons.badge_outlined,
    Icons.people_outline,
    Icons.build_outlined,
    Icons.payments_outlined,
    Icons.meeting_room_outlined,
    Icons.sensors_outlined,
  ];

  Future<void> _logout() async {
    await AppConfig.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const SetupScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F5F2),
      appBar: AppBar(
        title: Text('HostelOS — ${_titles[_index]}'),
        backgroundColor: const Color(0xFF1A1D29),
        foregroundColor: Colors.white,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF1A1D29)),
              child: Row(
                children: [
                  const Text('Hostel', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  const Text('OS', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFC25E2E))),
                ],
              ),
            ),
            for (int i = 0; i < _titles.length; i++)
              ListTile(
                leading: Icon(_icons[i]),
                title: Text(_titles[i]),
                selected: _index == i,
                onTap: () {
                  setState(() => _index = i);
                  Navigator.pop(context);
                },
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Switch account'),
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: IndexedStack(index: _index, children: _tabs),
    );
  }
}
