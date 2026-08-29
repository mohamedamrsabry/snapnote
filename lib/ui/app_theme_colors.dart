import 'package:flutter/material.dart';

// Small helpers so screens can pick a light or dark variant of the app's
// hand-picked neutral colors (rather than hardcoding one brightness),
// without having to redesign every custom-colored widget around Material
// 3's full ColorScheme.
bool isDarkContext(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

Color scaffoldBg(BuildContext context) =>
    isDarkContext(context) ? const Color(0xFF1C1C1E) : const Color(0xFFF5F5F7);

Color pillColor(BuildContext context) =>
    isDarkContext(context) ? const Color(0xFF2C2C2E) : const Color(0xFFE4E4EA);

Color elevatedPillColor(BuildContext context) =>
    isDarkContext(context) ? const Color(0xFF3A3A3C) : const Color(0xFFD8D8DF);

Color primaryTextColor(BuildContext context) =>
    isDarkContext(context) ? Colors.white : Colors.black87;

Color secondaryTextColor(BuildContext context, [double opacity = 0.7]) =>
    (isDarkContext(context) ? Colors.white : Colors.black).withValues(
      alpha: opacity,
    );
