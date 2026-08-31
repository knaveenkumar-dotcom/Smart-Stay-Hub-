import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/common.dart';

class WardenMaintenanceTab extends StatefulWidget {
  const WardenMaintenanceTab({super.key});

  @override
  State<WardenMaintenanceTab> createState() => _WardenMaintenanceTabState();
}

class _WardenMaintenanceTabState extends State<WardenMaintenanceTab> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService.getMaintenance();
  }

  void _reload() => setState(() => _future = ApiService.getMaintenance());

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Maintenance Requests', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          AsyncListView<dynamic>(
            future: _future,
            emptyMessage: 'No maintenance requests.',
            builder: (context, rows) => Column(
              children: rows.map((m) {
                final resolved = m['status'] == 'resolved';
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE4E2DC)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(m['category'], style: const TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(width: 8),
                              StatusBadge(status: m['priority']),
                            ],
                          ),
                          StatusBadge(status: m['status']),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(m['description'] ?? '', style: const TextStyle(color: kSlate, fontSize: 13)),
                      if (!resolved) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () async {
                              await ApiService.updateMaintenanceStatus(m['id'], 'resolved');
                              _reload();
                            },
                            child: const Text('Mark Resolved'),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
