import 'package:flutter/material.dart';

/// 可选主题色，通过 Material 3 种子色生成浅色 / 深色配色。
enum AccentTheme {
  blue('经典蓝', Color(0xFF1E5CBA)),
  teal('青碧', Color(0xFF00796B)),
  green('松绿', Color(0xFF2E7D32)),
  orange('落日橙', Color(0xFFEF6C00)),
  purple('紫罗兰', Color(0xFF6A1B9A)),
  rose('玫瑰红', Color(0xFFC2185B));

  const AccentTheme(this.label, this.seed);

  final String label;
  final Color seed;

  static AccentTheme fromName(String? name) {
    for (final AccentTheme accent in values) {
      if (accent.name == name) return accent;
    }
    return blue;
  }
}
