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

  Color _hexToColor(String hex) {
    final clean = hex.replaceFirst('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: _hexToColor(colorHex),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.9,
        ),
      ),
    );
  }
}
