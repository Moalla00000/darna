import 'package:flutter/material.dart';

enum DoorStatus { ready, opening, opened, error }

class DoorStatusChip extends StatelessWidget {
  final DoorStatus status;

  const DoorStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    late Color backgroundColor;
    late Color foregroundColor;
    late IconData icon;
    late String label;

    switch (status) {
      case DoorStatus.ready:
        backgroundColor = Colors.blue.withValues(alpha: 0.1);
        foregroundColor = Colors.blue.shade700;
        icon = Icons.info_outline_rounded;
        label = 'System Ready';
        break;
      case DoorStatus.opening:
        backgroundColor = Colors.orange.withValues(alpha: 0.1);
        foregroundColor = Colors.orange.shade800;
        icon = Icons.hourglass_top_rounded;
        label = 'Opening Door...';
        break;
      case DoorStatus.opened:
        backgroundColor = Colors.green.withValues(alpha: 0.1);
        foregroundColor = Colors.green.shade700;
        icon = Icons.check_circle_outline_rounded;
        label = 'Door Opened';
        break;
      case DoorStatus.error:
        backgroundColor = Colors.red.withValues(alpha: 0.1);
        foregroundColor = Colors.red.shade700;
        icon = Icons.error_outline_rounded;
        label = 'Failed to Open';
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: foregroundColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: foregroundColor, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: foregroundColor, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
