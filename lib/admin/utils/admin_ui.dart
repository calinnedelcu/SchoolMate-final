import 'dart:math';

import 'package:flutter/material.dart';

final Random _rng = Random.secure();

const String _passwordChars =
    'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#';

String randPassword(int len) => List.generate(
      len,
      (_) => _passwordChars[_rng.nextInt(_passwordChars.length)],
    ).join();

String initials(String name) {
  final trimmed = name.trim();
  final spaceIdx = trimmed.indexOf(' ');
  if (spaceIdx > 0 && spaceIdx < trimmed.length - 1) {
    return '${trimmed[0]}${trimmed[spaceIdx + 1]}'.toUpperCase();
  }
  return trimmed.isNotEmpty ? trimmed[0].toUpperCase() : '?';
}

const List<Color> _avatarPalette = [
  Color(0xFF7FA8D9),
  Color(0xFF7CAAD6),
  Color(0xFFFF8A65),
  Color(0xFFADCAE3),
  Color(0xFFCE93D8),
  Color(0xFF84D0E4),
  Color(0xFFFFCC80),
  Color(0xFF8FAFC4),
];

Color avatarColor(String name) =>
    _avatarPalette[name.hashCode.abs() % _avatarPalette.length];

String formatClassName(String classId, {String prefix = 'Class'}) {
  if (classId.isEmpty) return '-';
  if (classId.toLowerCase().startsWith(prefix.toLowerCase())) return classId;

  final original = classId.trim();
  final match = RegExp(r'^(\d+)(.*)$').firstMatch(original);

  if (match != null) {
    final numStr = match.group(1)!;
    final letter = match.group(2)!.trim();

    String roman = numStr;
    if (numStr == '9') {
      roman = 'IX';
    } else if (numStr == '10') {
      roman = 'X';
    } else if (numStr == '11') {
      roman = 'XI';
    } else if (numStr == '12') {
      roman = 'XII';
    }

    if (letter.isNotEmpty) {
      return '$prefix $roman $letter';
    }
    return '$prefix $roman';
  }

  return '$prefix $original';
}
