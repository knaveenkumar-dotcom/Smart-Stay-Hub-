import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/common.dart';

class WardenSensorsTab extends StatefulWidget {
  const WardenSensorsTab({super.key});

  @override
  State<WardenSensorsTab> createState() => _WardenSensorsTabState();
}

class _WardenSensorsTabState extends State<WardenSensorsTab> {
  static const int gasAlertThreshold = 1800;
  static const int waterLowThreshold = 20;

  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService.getLatestSensors();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => setState(() => _future = ApiService.getLatestSensors()),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Sensors', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Live readings from your ESP32 nodes. Pull to refresh.', style: TextStyle(color: kSlate)),
          const SizedBox(height: 16),
          AsyncListView<dynamic>(
            future: _future,
            emptyMessage: 'No sensor data yet — check your ESP32 is powered and connected.',
            builder: (context, rows) => Column(
              children: rows.map((r) {
                final gasHigh = (r['gas_raw'] ?? 0) > gasAlertThreshold;
                final waterLow = r['water_level_pct'] != null && r['water_level_pct'] < waterLowThreshold;
                final doorOpen = r['door_closed'] == 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE4E2DC)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r['device_id'] ?? 'Unknown device', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          _Reading(icon: '🌡️', label: '${r['temperature_c'] ?? '-'}°C'),
                          _Reading(icon: '💧', label: '${r['humidity_pct'] ?? '-'}%'),
                          _Reading(icon: '🔥', label: 'Gas ${r['gas_raw'] ?? '-'}', alert: gasHigh),
                          _Reading(icon: '🚰', label: 'Tank ${r['water_level_pct'] ?? '-'}%', alert: waterLow),
                          _Reading(icon: '🚪', label: doorOpen ? 'Open' : 'Closed', alert: doorOpen),
                          _Reading(icon: '🚶', label: r['motion_detected'] == 1 ? 'Motion' : 'No motion'),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('${r['timestamp']}', style: const TextStyle(fontSize: 11, color: kSlate)),
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

class _Reading extends StatelessWidget {
  final String icon;
  final String label;
  final bool alert;
  const _Reading({required this.icon, required this.label, this.alert = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: alert ? kBad.withOpacity(0.1) : const Color(0xFFF6F5F2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$icon $label',
          style: TextStyle(fontSize: 13, fontWeight: alert ? FontWeight.bold : FontWeight.normal, color: alert ? kBad : kInk)),
    );
  }
}
