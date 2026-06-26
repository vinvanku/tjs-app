import 'package:flutter/material.dart';

/// A badge widget that displays the number of days remaining until a target date.
///
/// Color coding:
/// - Red: ≤3 days remaining (urgent)
/// - Orange: ≤7 days remaining (warning)
/// - Green: >7 days remaining (safe)
/// - Grey: Expired
class CountdownBadge extends StatelessWidget {
  final DateTime targetDate;

  const CountdownBadge({
    super.key,
    required this.targetDate,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final difference = target.difference(today).inDays;

    final (String label, Color bgColor, Color textColor) = _resolve(difference);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: bgColor.withOpacity(0.3), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  (String, Color, Color) _resolve(int daysLeft) {
    if (daysLeft < 0) {
      return ('Expired', Colors.grey, Colors.grey.shade700);
    } else if (daysLeft == 0) {
      return ('Today!', Colors.red, Colors.red.shade700);
    } else if (daysLeft <= 3) {
      return ('${daysLeft}d left', Colors.red, Colors.red.shade700);
    } else if (daysLeft <= 7) {
      return ('${daysLeft}d left', Colors.orange, Colors.orange.shade800);
    } else {
      return ('${daysLeft}d left', Colors.green, Colors.green.shade700);
    }
  }
}
