// widgets/animated_feature_card.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class AnimatedFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final LinearGradient iconGradient;

  const AnimatedFeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.iconGradient,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Card(
          margin: EdgeInsets.zero, // Controlled by PageView padding
          elevation: 10,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          shadowColor: Colors.black.withOpacity(0.15),
          child: Container(
            width: constraints.maxWidth, // Card takes available width from PageView
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              // Optional: Add a subtle inner shadow or border for depth
              border: Border.all(color: Colors.grey.withOpacity(0.1), width: 0.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: iconGradient,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: iconGradient.colors.first.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: FaIcon(
                    icon,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF666666),
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}