import 'package:flutter/material.dart';

class SwipeActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const SwipeActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  // At rest each action only gets its normal reveal width (a quarter of the
  // screen or less), so it renders as a small floating circle. Keep
  // swiping past the button reveal and flutter_slidable's dismiss motion
  // grows the furthest action's width toward the full screen width — past
  // that point this switches to a filled rounded rect that stretches to
  // fill the growing space, so it visually expands as the swipe nears the
  // edge, and releasing there triggers the action instead of just tapping.
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final expandThreshold = MediaQuery.sizeOf(context).width * 0.32;
        final isExpanding = constraints.maxWidth > expandThreshold;

        if (!isExpanding) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        );
      },
    );
  }
}
