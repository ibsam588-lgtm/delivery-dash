/// Isometric coordinate utilities for the Paperboy-style diagonal perspective.
library;

import 'package:flame/components.dart';

/// Convert isometric world coords to screen coords.
/// World: x = horizontal position, y = depth (distance into screen).
/// Screen tile ratio is 2:1 (tileW=64, tileH=32).
Vector2 isoToScreen(
  double worldX,
  double worldY,
  double screenW,
  double screenH,
) {
  final screenX = (screenW / 2) + (worldX - worldY) * 32;
  final screenY = (screenH * 0.3) + (worldX + worldY) * 16;
  return Vector2(screenX, screenY);
}
