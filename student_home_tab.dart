import 'package:flutter/material.dart';
import '../../config.dart';
import '../../services/api_service.dart';
import '../../widgets/common.dart';

class StudentHomeTab extends StatefulWidget {
  const StudentHomeTab({super.key});

  @override
  State<StudentHomeTab> createState() => _StudentHomeTabState();
}

class _StudentHomeTabState extends State<StudentHomeTab> {
  late Future<List<dynamic>> _attendanceFuture;
  late Future<List<dynamic>> _feesFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _attendanceFuture = ApiService.getAttendance(studentId: AppConfig.instance.studentId);
    _feesFuture = ApiService.getFees(studentId: AppConfig.instance.studentId, status: 'pending');
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => setState(_reload),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Hi, ${AppConfig.instance.studentName ?? 'Student'} 👋',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Here\'s what\'s happening at your hostel', style: TextStyle(color: kSlate)),
          const SizedBox(height: 20),

          SectionCard(
            title: 'Your Latest Status',
            child: AsyncListView<dynamic>(
              future: _attendanceFuture,
              emptyMessage: 'No attendance recorded yet — tap your RFID card at the gate.',
              builder: (context, rows) {
                final latest = rows.first;
                final isIn = latest['event_type'] == 'in';
                return Row(
                  children: [
                    Icon(isIn ? Icons.check_circle : Icons.logout, color: isIn ? kGood : kWarn, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isIn ? 'You are currently IN' : 'You are currently OUT',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text('Last scan: ${latest['timestamp']}', style: const TextStyle(fontSize: 12, color: kSlate)),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          SectionCard(
            title: 'Pending Fees',
            child: AsyncListView<dynamic>(
              future: _feesFuture,
              emptyMessage: 'No pending fees. You\'re all clear! 🎉',
              builder: (context, rows) => Column(
                children: rows.map((f) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${f['month']}'),
                      Text('₹${f['amount']}', style: const TextStyle(fontWeight: FontWeight.bold, color: kWarn)),
                    ],
                  ),
                )).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
