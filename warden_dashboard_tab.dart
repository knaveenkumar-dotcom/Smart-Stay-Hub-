import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/common.dart';

class WardenDashboardTab extends StatefulWidget {
  const WardenDashboardTab({super.key});

  @override
  State<WardenDashboardTab> createState() => _WardenDashboardTabState();
}

class _WardenDashboardTabState extends State<WardenDashboardTab> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService.getDashboard();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => setState(() => _future = ApiService.getDashboard()),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Overview', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          FutureBuilder<Map<String, dynamic>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text('Could not reach server: ${snapshot.error}', style: const TextStyle(color: kBad)),
                );
              }
              final d = snapshot.data!;
              return GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: [
                  StatTile(value: '${d['totalStudents']}', label: 'Students'),
                  StatTile(value: '${d['studentsInside']}', label: 'Inside Now', color: kGood),
                  StatTile(value: '${d['vacantBeds'] ?? 0}', label: 'Vacant Beds'),
                  StatTile(value: '${d['activeVisitors']}', label: 'Active Visitors'),
                  StatTile(value: '${d['openMaintenance']}', label: 'Open Tickets', color: kWarn),
                  StatTile(value: '${d['pendingFees']}', label: 'Pending Fees', color: kBad),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
