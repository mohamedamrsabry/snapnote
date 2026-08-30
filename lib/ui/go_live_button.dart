import 'package:flutter/material.dart';

import 'app_theme_colors.dart';

// Presentation-only: no provider reads, no plugin, no permission logic.
// The screen hands it a bool and a callback.
class GoLiveButton extends StatefulWidget {
  final bool isLive;
  final VoidCallback? onPressed;

  const GoLiveButton({super.key, required this.isLive, this.onPressed});

  @override
  State<GoLiveButton> createState() => _GoLiveButtonState();
}

class _GoLiveButtonState extends State<GoLiveButton>
    with SingleTickerProviderStateMixin {
  // Same AnimationController + repeat() pattern as _RecordingModal's pulse
  // rings, just a breathing opacity on a small dot rather than an
  // expanding ring — this dot is 14px, too small for a ring to read.
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.isLive) _pulseController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant GoLiveButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLive && !oldWidget.isLive) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isLive && oldWidget.isLive) {
      _pulseController
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: widget.isLive ? elevatedPillColor(context) : pillColor(context),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: widget.onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final opacity = widget.isLive
                      ? 0.4 + _pulseController.value * 0.6
                      : 1.0;
                  return Opacity(opacity: opacity, child: child);
                },
                child: Icon(
                  widget.isLive ? Icons.circle : Icons.circle_outlined,
                  size: 14,
                  color: widget.isLive
                      ? const Color(0xFF8E8E93)
                      : secondaryTextColor(context, 0.7),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.isLive ? 'Live' : 'Go Live',
                style: TextStyle(
                  color: primaryTextColor(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
