// widgets/custom_app_bar.dart
import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent, // Make app bar transparent
      elevation: 0, // No shadow
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF2196F3),
                  Color(0xFFFF7043),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.directions_run, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          const Text(
            'Stride',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
      // Optionally add leading/trailing icons if needed
      // leading: IconButton(icon: const Icon(Icons.menu, color: Colors.white), onPressed: () {}),
      // actions: [
      //   IconButton(icon: const Icon(Icons.person, color: Colors.white), onPressed: () {}),
      // ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}