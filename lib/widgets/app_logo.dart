import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final TextStyle? textStyle;

  const AppLogo({
    super.key,
    this.size = 28,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF2196F3), // Blue
                Color(0xFFFF7043), // Orange
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(size / 4),
          ),
          child: Icon(
            Icons.directions_run, // Example icon, could be a custom SVG later
            color: Colors.white,
            size: size * 0.6,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Stride',
          style: textStyle ??
              TextStyle(
                fontSize: size * 0.8,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
        ),
      ],
    );
  }
}