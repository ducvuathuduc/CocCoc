import 'package:flutter/material.dart';

/// Source node geometry with the owner's requested tactile timing targets.
abstract final class PathMotionTokens {
  static const pressDuration = Duration(milliseconds: 100);
  static const releaseDuration = Duration(milliseconds: 250);
  static const pressCurve = Curves.easeOutCubic;
  static const releaseCurve = Curves.easeOutBack;
  static const pressedScale = .94;
  static const depth = 7.0;
}
