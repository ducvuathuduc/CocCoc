import 'package:flutter/material.dart';

class Friend {
  const Friend({
    required this.name,
    required this.xp,
    required this.color,
    required this.isFollowing,
    required this.isFollower,
    this.flagColors = const [
      Color(0xFF1C6FA1),
      Colors.white,
      Color(0xFFA3302D),
    ],
  });

  final String name;
  final int xp;
  final Color color;
  final bool isFollowing;
  final bool isFollower;
  final List<Color> flagColors;
}
