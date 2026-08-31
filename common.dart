import 'package:flutter/material.dart';

const Color kInk = Color(0xFF1A1D29);
const Color kAccent = Color(0xFFC25E2E);
const Color kGood = Color(0xFF2F7D5E);
const Color kWarn = Color(0xFFB8862B);
const Color kBad = Color(0xFFA8412F);
const Color kSlate = Color(0xFF4A5068);

/// Small stat tile used on dashboard-style screens (e.g. "12 Students").
class StatTile extends StatelessWidget {
  final String value;
  final String label;
  final Color? color;
  const StatTile({super.key, required this.value, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E2DC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color ?? kInk)),
          const SizedBox(height: 2),
          Text(label.toUpperCase(),
              style: const TextStyle(fontSize: 11, color: kSlate, letterSpacing: 0.4)),
        ],
      ),
    );
  }
}

/// Colored pill for status values like "paid", "pending", "resolved".
class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status.toLowerCase()) {
      case 'paid':
      case 'resolved':
      case 'in':
        bg = kGood.withOpacity(0.12);
        fg = kGood;
        break;
      case 'overdue':
        bg = kBad.withOpacity(0.12);
        fg = kBad;
        break;
      default: // pending, open, out, in_progress
        bg = kWarn.withOpacity(0.12);
        fg = kWarn;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(status.replaceAll('_', ' '),
          style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

/// A titled card wrapper used to group content on each tab.
class SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const SectionCard({super.key, required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E2DC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Placeholder shown when a list has no data yet.
class EmptyHint extends StatelessWidget {
  final String message;
  const EmptyHint({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(message, style: const TextStyle(color: kSlate, fontSize: 13)),
      ),
    );
  }
}

/// Standard loading + error + data wrapper for FutureBuilder-based screens.
class AsyncListView<T> extends StatelessWidget {
  final Future<List<T>> future;
  final Widget Function(BuildContext, List<T>) builder;
  final String emptyMessage;
  const AsyncListView({super.key, required this.future, required this.builder, this.emptyMessage = 'No data yet.'});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<T>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('Error: ${snapshot.error}', style: const TextStyle(color: kBad, fontSize: 13)),
          );
        }
        final data = snapshot.data ?? [];
        if (data.isEmpty) return EmptyHint(message: emptyMessage);
        return builder(context, data);
      },
    );
  }
}
