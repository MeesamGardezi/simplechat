import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  final String name;
  final String colorHex;
  final double radius;

  const UserAvatar({
    super.key,
    required this.name,
    required this.colorHex,
    this.radius = 20,
  });

  Color _parse(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
    } catch (_) {
      return const Color(0xFF075E54);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: _parse(colorHex),
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: radius * 0.85,
          height: 1,
        ),
      ),
    );
  }
}
