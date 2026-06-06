import 'package:flutter/material.dart';

class GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final LinearGradient gradient;
  final Icon? icon;
  final EdgeInsetsGeometry padding;
  final double? width; // ✅ ADD THIS

  const GradientButton({
    Key? key,
    required this.text,
    required this.onPressed,
    required this.gradient,
    this.icon,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    this.width, // ✅ ADD THIS
  }) : super(key: key);


  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(30),
          child: Padding(
            padding: padding, // <<-- USED HERE
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  text,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (icon != null) const SizedBox(width: 8),
                if (icon != null) icon!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}