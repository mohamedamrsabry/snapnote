import 'package:flutter/material.dart';

final List<Color> tagColorPalette = List.generate(32, (i) {
  final hue = (360 / 32) * i;
  return HSLColor.fromAHSL(1.0, hue, 0.65, 0.75).toColor();
});

// tagColorPalette is laid out in hue order (nice for the swatch picker to
// scan), so cycling through it by plain creation index would hand out
// neighboring hues to consecutively-created notes/tags, reading as a smooth
// gradient instead of a varied palette. 7 is coprime with the palette's
// length (32), so multiplying by it jumps to a well-spread color each time
// while still covering all 32 colors before repeating.
const int _paletteAssignmentStep = 7;

Color paletteColorForCreationIndex(int index) {
  return tagColorPalette[(index * _paletteAssignmentStep) %
      tagColorPalette.length];
}
