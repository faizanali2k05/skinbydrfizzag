import 'package:flutter/material.dart';
import '../constants/styles.dart';

/// Pill-shaped status indicator (used by appointments + chats).
class StatusChip extends StatelessWidget {
  final String status;
  final double fontSize;

  const StatusChip({
    super.key,
    required this.status,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppStyles.statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(38),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        status.isEmpty ? '—' : status[0].toUpperCase() + status.substring(1),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: fontSize,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
